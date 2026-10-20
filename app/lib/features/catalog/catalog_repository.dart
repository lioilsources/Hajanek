import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;

import '../../core/content_ref.dart';
import '../../core/script/script.dart';
import 'catalog_models.dart';
import 'catalog_sync.dart';

const defaultCatalogUrl = String.fromEnvironment(
  'CATALOG_URL',
  defaultValue: 'https://lioilsources.github.io/hajanek-content/catalog.json',
);

/// Bundled tales whose script is `status: draft`. Must be false for release
/// (`--dart-define=INCLUDE_DRAFTS=false`); the published catalog never has
/// drafts anyway.
const includeDrafts = bool.fromEnvironment('INCLUDE_DRAFTS', defaultValue: true);

class CatalogSnapshot {
  const CatalogSnapshot({required this.catalog, required this.local});
  final Catalog catalog;
  final LocalContent local;

  CatalogSnapshot copyWith({Catalog? catalog, LocalContent? local}) =>
      CatalogSnapshot(catalog: catalog ?? this.catalog, local: local ?? this.local);
}

enum SyncResult { upToDate, updated }

class HashMismatchException implements Exception {
  HashMismatchException(this.path);
  final String path;
  @override
  String toString() => 'HashMismatchException: $path';
}

/// Bundled catalog → local (downloaded) catalog → remote check.
class CatalogRepository {
  CatalogRepository({
    required this.loadAsset,
    required this.listBundledAssets,
    required this.docsDir,
    http.Client? client,
    Uri? remoteUrl,
    this.drafts = includeDrafts,
  })  : client = client ?? http.Client(),
        remoteUrl = remoteUrl ?? Uri.parse(defaultCatalogUrl);

  static const bundledCatalogAsset = 'assets/catalog/catalog.json';

  /// Text of a bundled asset (rootBundle.loadString in the app).
  final Future<String> Function(String asset) loadAsset;
  final bool drafts;
  final Future<Set<String>> Function() listBundledAssets;
  final Future<Directory> Function() docsDir;
  final http.Client client;
  final Uri remoteUrl;

  late Directory _root;
  Directory get _blobs => Directory('${_root.path}/blobs');
  Directory get _tmp => Directory('${_root.path}/tmp');
  File get _catalogFile => File('${_root.path}/catalog.json');

  Future<CatalogSnapshot> init() async {
    var bundled = Catalog.fromJson(
        jsonDecode(await loadAsset(bundledCatalogAsset)) as Map<String, dynamic>);
    final assets = await listBundledAssets();
    final bundledFiles = {
      for (final f in bundled.files)
        if (assets.contains('assets/${f.path}')) f.path: f.sha256,
    };

    _root = Directory('${(await docsDir()).path}/catalog');
    await _blobs.create(recursive: true);
    if (await _tmp.exists()) await _tmp.delete(recursive: true);
    await _tmp.create(recursive: true);

    if (!drafts) {
      final hidden = <String>{};
      for (final t in bundled.tales) {
        final s = t.script();
        if (!assets.contains('assets/${s.path}')) continue;
        if (parseScript(await loadAsset('assets/${s.path}')).isDraft) hidden.add(t.id);
      }
      bundled = bundled.withoutTales(hidden);
    }

    var catalog = bundled;
    if (await _catalogFile.exists()) {
      try {
        final stored = Catalog.fromJson(
            jsonDecode(await _catalogFile.readAsString()) as Map<String, dynamic>);
        if (stored.version > bundled.version) catalog = stored;
      } on Object {
        // Corrupt local copy: fall back to the bundle, next sync rewrites it.
      }
    }

    return CatalogSnapshot(
      catalog: catalog,
      local: LocalContent(bundled: bundledFiles, blobs: await _listBlobs(), blobDir: _blobs.path),
    );
  }

  Future<Set<String>> _listBlobs() async {
    final out = <String>{};
    await for (final e in _blobs.list()) {
      if (e is! File) continue;
      final name = e.uri.pathSegments.last;
      final sha = name.split('.').first;
      if (sha.length == 64) out.add(sha);
    }
    return out;
  }

  /// Fetch the remote catalog; if newer, download changed files (verified by
  /// sha256) and only then swap catalog.json. Any failure leaves the current
  /// catalog untouched.
  Future<(SyncResult, CatalogSnapshot)> sync(CatalogSnapshot current) async {
    final resp = await client.get(remoteUrl).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw HttpException('catalog ${resp.statusCode}', uri: remoteUrl);
    }
    final body = utf8.decode(resp.bodyBytes);
    final json = jsonDecode(body) as Map<String, dynamic>;
    // An app that is too old (or too new) for the published schema keeps
    // what it has instead of reporting an error.
    if (Catalog.schemaOf(json) != supportedCatalogSchema) return (SyncResult.upToDate, current);
    final remote = Catalog.fromJson(json);
    final plan = planSync(current: current.catalog, remote: remote, local: current.local);
    if (!plan.apply) return (SyncResult.upToDate, current);

    var local = current.local;
    for (final f in plan.downloads) {
      await _download(remote.urlFor(platformPath(f.path)), f);
      local = local.withBlob(f.sha256);
    }

    final tmp = File('${_tmp.path}/catalog.json.part');
    await tmp.writeAsString(body, flush: true);
    await tmp.rename(_catalogFile.path);

    for (final sha in plan.garbage) {
      await for (final e in _blobs.list()) {
        if (e is File && e.uri.pathSegments.last.startsWith(sha)) await e.delete();
      }
    }
    local = local.withBlobs(local.blobs.difference(plan.garbage));
    return (SyncResult.updated, CatalogSnapshot(catalog: remote, local: local));
  }

  /// Text of a script (bundled or downloaded).
  Future<String> loadText(ContentRef ref) => switch (ref) {
        AssetRef(:final asset) => loadAsset(asset),
        FileRef(:final path) => File(path).readAsString(),
      };

  Future<void> _download(Uri url, CatalogFile f) async {
    final part = File('${_tmp.path}/${f.sha256}.part');
    final resp = await client.send(http.Request('GET', url));
    if (resp.statusCode != 200) {
      throw HttpException('download ${resp.statusCode}', uri: url);
    }
    final sink = part.openWrite();
    final digestSink = _DigestSink();
    final hasher = crypto.sha256.startChunkedConversion(digestSink);
    try {
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        hasher.add(chunk);
      }
    } finally {
      await sink.close();
    }
    hasher.close();
    if (digestSink.value.toString() != f.sha256) {
      await part.delete();
      throw HashMismatchException(f.path);
    }
    await part.rename(blobPath(_blobs.path, f));
  }
}

class _DigestSink implements Sink<crypto.Digest> {
  late crypto.Digest value;
  @override
  void add(crypto.Digest data) => value = data;
  @override
  void close() {}
}
