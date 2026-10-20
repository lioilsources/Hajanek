import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;

import 'catalog_models.dart';
import 'catalog_sync.dart';

const defaultCatalogUrl = String.fromEnvironment(
  'CATALOG_URL',
  defaultValue: 'https://lioilsources.github.io/hajanek-content/catalog.json',
);

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
    required this.loadBundledCatalog,
    required this.listBundledAssets,
    required this.docsDir,
    http.Client? client,
    Uri? remoteUrl,
  })  : client = client ?? http.Client(),
        remoteUrl = remoteUrl ?? Uri.parse(defaultCatalogUrl);

  final Future<String> Function() loadBundledCatalog;
  final Future<Set<String>> Function() listBundledAssets;
  final Future<Directory> Function() docsDir;
  final http.Client client;
  final Uri remoteUrl;

  late Directory _root;
  Directory get _blobs => Directory('${_root.path}/blobs');
  Directory get _tmp => Directory('${_root.path}/tmp');
  File get _catalogFile => File('${_root.path}/catalog.json');

  Future<CatalogSnapshot> init() async {
    final bundled = Catalog.fromJson(jsonDecode(await loadBundledCatalog()) as Map<String, dynamic>);
    final assets = await listBundledAssets();
    final bundledFiles = {
      for (final f in bundled.files)
        if (assets.contains('assets/${f.path}')) f.path: f.sha256,
    };

    _root = Directory('${(await docsDir()).path}/catalog');
    await _blobs.create(recursive: true);
    if (await _tmp.exists()) await _tmp.delete(recursive: true);
    await _tmp.create(recursive: true);

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
    final remote = Catalog.fromJson(jsonDecode(body) as Map<String, dynamic>);
    final plan = planSync(current: current.catalog, remote: remote, local: current.local);
    if (!plan.apply) return (SyncResult.upToDate, current);

    var local = current.local;
    for (final f in plan.downloads) {
      await _download(remote.urlFor(platformAudioPath(f.path)), f);
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

  /// On-demand download (tale tracks). Returns updated local content.
  Future<LocalContent> download(
    CatalogSnapshot snap,
    CatalogFile f, {
    void Function(double progress)? onProgress,
  }) async {
    await _download(snap.catalog.urlFor(platformAudioPath(f.path)), f, onProgress: onProgress);
    return snap.local.withBlob(f.sha256);
  }

  Future<void> _download(Uri url, CatalogFile f, {void Function(double)? onProgress}) async {
    final part = File('${_tmp.path}/${f.sha256}.part');
    final resp = await client.send(http.Request('GET', url));
    if (resp.statusCode != 200) {
      throw HttpException('download ${resp.statusCode}', uri: url);
    }
    final sink = part.openWrite();
    final digestSink = _DigestSink();
    final hasher = crypto.sha256.startChunkedConversion(digestSink);
    var received = 0;
    final total = resp.contentLength ?? f.bytes;
    try {
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        if (onProgress != null && total > 0) onProgress((received / total).clamp(0.0, 1.0));
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
