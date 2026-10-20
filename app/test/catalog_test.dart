import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajanek/core/audio_ref.dart';
import 'package:hajanek/features/catalog/catalog_models.dart';
import 'package:hajanek/features/catalog/catalog_repository.dart';
import 'package:hajanek/features/catalog/catalog_sync.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> bundledJson() =>
    jsonDecode(File('assets/catalog/catalog.json').readAsStringSync()) as Map<String, dynamic>;

String sha(String s) => sha256.convert(utf8.encode(s)).toString();

Map<String, dynamic> miniJson({
  int version = 1,
  String seaSha = '',
  String taleSha = '',
}) =>
    {
      'schema': 1,
      'version': version,
      'generated_at': '2026-10-20T03:12:00Z',
      'base_url': 'https://example.test/c',
      'voices': [
        {'id': 'mama', 'label': 'Měkký', 'free': true},
      ],
      'tales': [
        {
          'id': 'budulinek',
          'title': 'Budulínek',
          'ambient': 'sea',
          'tracks': [
            {
              'voice': 'mama',
              'length_min': 10,
              'path': 'audio/budulinek/mama/10.opus',
              'duration_s': 600.0,
              'bytes': 4,
              'sha256': taleSha.isEmpty ? sha('tale-v1') : taleSha,
            },
          ],
        },
      ],
      'ambient': [
        {
          'id': 'sea',
          'title': 'Moře',
          'path': 'ambient/sea.opus',
          'duration_s': 90.0,
          'bytes': 6,
          'sha256': seaSha.isEmpty ? sha('sea-v1') : seaSha,
        },
      ],
      'presets': [
        {
          'id': 'plaz-vecer',
          'title': 'Pláž večer',
          'layers': [
            {'ambient': 'sea', 'volume': 0.8},
          ],
        },
      ],
    };

void main() {
  group('parsing', () {
    test('bundled catalog conforms to the contract', () {
      final c = Catalog.fromJson(bundledJson());
      expect(c.schema, 1);
      expect(c.tales, hasLength(10));
      expect(c.ambient.map((a) => a.id), unorderedEquals([
        'sea', 'rain', 'stream', 'fireplace', 'wind', 'night-meadow', 'pink-noise', 'brown-noise', //
      ]));
      expect(c.voice('mama')!.label, 'Měkký');
      expect(c.voice('tata')!.label, 'Hluboký');
      for (final t in c.tales) {
        expect(t.track('mama'), isNotNull, reason: t.id);
        expect(t.track('tata'), isNotNull, reason: t.id);
        expect(c.ambientById(t.ambient), isNotNull, reason: '${t.id} ambient');
      }
      for (final p in c.presets) {
        expect(p.layers.length, inInclusiveRange(1, 3));
        for (final l in p.layers) {
          expect(c.ambientById(l.ambient), isNotNull);
        }
      }
      expect(c.urlFor('ambient/sea.opus').toString(),
          'https://lioilsources.github.io/hajanek-content/ambient/sea.opus');
    });

    test('bundled files match their hashes', () {
      final c = Catalog.fromJson(bundledJson());
      for (final f in c.files) {
        final file = File('assets/${f.path}');
        if (!file.existsSync()) continue;
        final bytes = file.readAsBytesSync();
        expect(sha256.convert(bytes).toString(), f.sha256, reason: f.path);
        expect(bytes.length, f.bytes, reason: f.path);
      }
    });

    test('rejects unknown schema, bad hash and oversized presets', () {
      expect(() => Catalog.fromJson({...miniJson(), 'schema': 2}),
          throwsA(isA<CatalogFormatException>()));
      expect(() => Catalog.fromJson(miniJson(seaSha: 'xyz')), throwsA(isA<CatalogFormatException>()));
      final tooMany = miniJson()
        ..['presets'] = [
          {
            'id': 'x',
            'title': 'X',
            'layers': List.filled(4, {'ambient': 'sea', 'volume': 0.5}),
          },
        ];
      expect(() => Catalog.fromJson(tooMany), throwsA(isA<CatalogFormatException>()));
    });

    test('base_url gets a trailing slash and volumes are clamped', () {
      final j = miniJson()
        ..['presets'] = [
          {
            'id': 'x',
            'title': 'X',
            'layers': [
              {'ambient': 'sea', 'volume': 1.7},
            ],
          },
        ];
      final c = Catalog.fromJson(j);
      expect(c.baseUrl, 'https://example.test/c/');
      expect(c.presets.single.layers.single.volume, 1.0);
    });
  });

  group('planSync', () {
    final v1 = Catalog.fromJson(miniJson());
    const blobDir = '/blobs';

    test('same or older version is a no-op', () {
      final local = LocalContent(bundled: const {}, blobs: const {}, blobDir: blobDir);
      expect(planSync(current: v1, remote: v1, local: local).apply, isFalse);
    });

    test('changed ambient is downloaded, unchanged bundled one is not', () {
      final local = LocalContent(
          bundled: {'ambient/sea.opus': sha('sea-v1')}, blobs: const {}, blobDir: blobDir);
      final same = Catalog.fromJson(miniJson(version: 2));
      expect(planSync(current: v1, remote: same, local: local).downloads, isEmpty);

      final changed = Catalog.fromJson(miniJson(version: 2, seaSha: sha('sea-v2')));
      final plan = planSync(current: v1, remote: changed, local: local);
      expect(plan.apply, isTrue);
      expect(plan.downloads.map((f) => f.path), ['ambient/sea.opus']);
    });

    test('tale tracks: update only those the parent downloaded', () {
      final remote = Catalog.fromJson(miniJson(version: 2, taleSha: sha('tale-v2')));
      final notDownloaded = LocalContent(
          bundled: {'ambient/sea.opus': sha('sea-v1')}, blobs: const {}, blobDir: blobDir);
      expect(planSync(current: v1, remote: remote, local: notDownloaded).downloads, isEmpty);

      final downloaded = LocalContent(
          bundled: {'ambient/sea.opus': sha('sea-v1')}, blobs: {sha('tale-v1')}, blobDir: blobDir);
      final plan = planSync(current: v1, remote: remote, local: downloaded);
      expect(plan.downloads.map((f) => f.path), ['audio/budulinek/mama/10.opus']);
      expect(plan.garbage, {sha('tale-v1')});
    });

    test('resolve prefers blob, then exact bundle, then stale bundle', () {
      final sea = v1.ambientById('sea')!;
      final tale = v1.tale('budulinek')!.track('mama')!;
      final local = LocalContent(
          bundled: {'ambient/sea.opus': sha('old')}, blobs: {sha('sea-v1')}, blobDir: blobDir);
      expect(local.resolve(sea), FileRef('/blobs/${sha('sea-v1')}.opus'));
      expect(local.withBlobs(const {}).resolve(sea), const AssetRef('assets/ambient/sea.opus'));
      expect(local.resolve(tale), isNull);
    });
  });

  group('repository', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('hajanek'));
    tearDown(() => tmp.deleteSync(recursive: true));

    CatalogRepository repo(http.Client client) => CatalogRepository(
          loadBundledCatalog: () async => jsonEncode(miniJson()),
          listBundledAssets: () async => {'assets/ambient/sea.opus'},
          docsDir: () async => tmp,
          client: client,
          remoteUrl: Uri.parse('https://example.test/c/catalog.json'),
        );

    test('downloads verified files, then swaps catalog atomically', () async {
      final v2 = miniJson(version: 2, seaSha: sha('sea-v2'));
      final client = MockClient((req) async => switch (req.url.path) {
            '/c/catalog.json' => http.Response.bytes(utf8.encode(jsonEncode(v2)), 200),
            '/c/ambient/sea.opus' => http.Response('sea-v2', 200),
            _ => http.Response('', 404),
          });
      final r = repo(client);
      final snap = await r.init();
      expect(snap.catalog.version, 1);

      final (result, next) = await r.sync(snap);
      expect(result, SyncResult.updated);
      expect(next.catalog.version, 2);
      final ref = next.local.resolve(next.catalog.ambientById('sea')!);
      expect(ref, isA<FileRef>());
      expect(File((ref! as FileRef).path).readAsStringSync(), 'sea-v2');

      // A fresh start picks up the stored catalog.
      final again = await repo(client).init();
      expect(again.catalog.version, 2);
      expect(again.local.blobs, {sha('sea-v2')});
    });

    test('hash mismatch keeps the old catalog', () async {
      final v2 = miniJson(version: 2, seaSha: sha('sea-v2'));
      final client = MockClient((req) async => switch (req.url.path) {
            '/c/catalog.json' => http.Response.bytes(utf8.encode(jsonEncode(v2)), 200),
            _ => http.Response('tampered', 200),
          });
      final r = repo(client);
      final snap = await r.init();
      await expectLater(r.sync(snap), throwsA(isA<HashMismatchException>()));
      final again = await repo(client).init();
      expect(again.catalog.version, 1);
      expect(again.local.blobs, isEmpty);
    });

    test('offline: sync throws, init still works', () async {
      final client = MockClient((_) async => throw const SocketException('offline'));
      final r = repo(client);
      final snap = await r.init();
      await expectLater(r.sync(snap), throwsA(isA<SocketException>()));
      expect(snap.catalog.tales.single.title, 'Budulínek');
    });

    test('on-demand download of a tale track', () async {
      final client = MockClient((req) async => http.Response('tale-v1', 200));
      final r = repo(client);
      final snap = await r.init();
      final track = snap.catalog.tale('budulinek')!.track('mama')!;
      expect(snap.local.resolve(track), isNull);
      final progress = <double>[];
      final local = await r.download(snap, track, onProgress: progress.add);
      expect(local.resolve(track), isA<FileRef>());
      expect(progress.last, 1.0);
    });
  });
}
