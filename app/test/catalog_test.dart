import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajanek/core/content_ref.dart';
import 'package:hajanek/core/script/script.dart';
import 'package:hajanek/features/catalog/catalog_models.dart';
import 'package:hajanek/features/catalog/catalog_repository.dart';
import 'package:hajanek/features/catalog/catalog_sync.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> bundledJson() =>
    jsonDecode(File('assets/catalog/catalog.json').readAsStringSync()) as Map<String, dynamic>;

String sha(String s) => sha256.convert(utf8.encode(s)).toString();

const scriptV1 = '---\nid: budulinek\nstatus: draft\n---\n## uvod\nAhoj.\n';
const scriptV2 = '---\nid: budulinek\nstatus: reviewed\n---\n## uvod\nDobrý večer.\n';

Map<String, dynamic> miniJson({
  int version = 1,
  String seaSha = '',
  String script = scriptV1,
}) =>
    {
      'schema': 2,
      'version': version,
      'generated_at': '2026-10-20T03:12:00Z',
      'base_url': 'https://example.test/c',
      'tales': [
        {
          'id': 'budulinek',
          'title': 'Budulínek',
          'ambient': 'sea',
          'scripts': [
            {
              'length_min': 10,
              'path': 'scripts/budulinek.10.md',
              'sha256': sha(script),
              'bytes': utf8.encode(script).length,
              'est_duration_s': 583,
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
      expect(c.schema, 2);
      expect(c.tales, hasLength(10));
      expect(c.ambient.map((a) => a.id), unorderedEquals([
        'sea', 'rain', 'stream', 'fireplace', 'wind', 'night-meadow', 'pink-noise', 'brown-noise', //
      ]));
      for (final t in c.tales) {
        final s = t.script();
        expect(s.lengthMin, 10, reason: t.id);
        expect(s.path, 'scripts/${t.id}.10.md');
        expect(File('assets/${s.path}').existsSync(), isTrue, reason: s.path);
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

    test('bundled files match their hashes, scripts their estimates', () {
      final c = Catalog.fromJson(bundledJson());
      for (final f in c.files) {
        final bytes = File('assets/${f.path}').readAsBytesSync();
        expect(sha256.convert(bytes).toString(), f.sha256, reason: f.path);
        expect(bytes.length, f.bytes, reason: f.path);
      }
      for (final t in c.tales) {
        final s = t.script();
        final parsed = parseScript(File('assets/${s.path}').readAsStringSync());
        expect(s.estDurationS, parsed.estimatedSeconds.roundToDouble(), reason: s.path);
        expect(parsed.meta['id'], t.id);
      }
    });

    test('bundled scripts are copies of content/', () {
      for (final f in Directory('assets/scripts').listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        final src = [File('../content/scripts/$name'), File('../content/scripts/gold/$name')]
            .firstWhere((x) => x.existsSync());
        expect(f.readAsStringSync(), src.readAsStringSync(),
            reason: '$name is stale: run dart run tool/bundle_content.dart');
      }
    });

    test('rejects unknown schema, bad hash and oversized presets', () {
      expect(() => Catalog.fromJson({...miniJson(), 'schema': 1}),
          throwsA(isA<CatalogFormatException>()));
      final noScripts = miniJson()..['tales'] = [
          {'id': 'x', 'title': 'X', 'scripts': []},
        ];
      expect(() => Catalog.fromJson(noScripts), throwsA(isA<CatalogFormatException>()));
      final badAmbient = miniJson()..['tales'] = [
          {
            'id': 'x',
            'title': 'X',
            'ambient': 'nope',
            'scripts': (miniJson()['tales'] as List).first['scripts'],
          },
        ];
      expect(() => Catalog.fromJson(badAmbient), throwsA(isA<CatalogFormatException>()));
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
        bundled: {'ambient/sea.opus': sha('sea-v1'), 'scripts/budulinek.10.md': sha(scriptV1)},
        blobs: const {},
        blobDir: blobDir,
      );
      final same = Catalog.fromJson(miniJson(version: 2));
      expect(planSync(current: v1, remote: same, local: local).downloads, isEmpty);

      final changed = Catalog.fromJson(miniJson(version: 2, seaSha: sha('sea-v2')));
      final plan = planSync(current: v1, remote: changed, local: local);
      expect(plan.apply, isTrue);
      expect(plan.downloads.map((f) => f.path), ['ambient/sea.opus']);
    });

    test('changed script is always downloaded; old blob becomes garbage', () {
      final remote = Catalog.fromJson(miniJson(version: 2, script: scriptV2));
      final local = LocalContent(
        bundled: {'ambient/sea.opus': sha('sea-v1'), 'scripts/budulinek.10.md': sha(scriptV1)},
        blobs: {sha('old-script')},
        blobDir: blobDir,
      );
      final plan = planSync(current: v1, remote: remote, local: local);
      expect(plan.downloads.map((f) => f.path), ['scripts/budulinek.10.md']);
      expect(plan.garbage, {sha('old-script')});
    });

    test('a newer remote schema is ignored', () {
      final local = LocalContent(bundled: const {}, blobs: const {}, blobDir: blobDir);
      final future = Catalog(
        schema: 3,
        version: 9,
        generatedAt: null,
        baseUrl: '',
        tales: const [],
        ambient: const [],
        presets: const [],
      );
      expect(planSync(current: v1, remote: future, local: local).apply, isFalse);
    });

    test('resolve prefers blob, then exact bundle, then stale bundle', () {
      final sea = v1.ambientById('sea')!;
      final script = v1.tale('budulinek')!.script();
      final local = LocalContent(
          bundled: {'ambient/sea.opus': sha('old')}, blobs: {sha('sea-v1')}, blobDir: blobDir);
      expect(local.resolve(sea), FileRef('/blobs/${sha('sea-v1')}.opus'));
      expect(local.withBlobs(const {}).resolve(sea), const AssetRef('assets/ambient/sea.opus'));
      expect(local.resolve(script), isNull);
    });
  });

  group('repository', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('hajanek'));
    tearDown(() => tmp.deleteSync(recursive: true));

    CatalogRepository repo(http.Client client, {bool drafts = true}) => CatalogRepository(
          loadAsset: (a) async => switch (a) {
            CatalogRepository.bundledCatalogAsset => jsonEncode(miniJson()),
            'assets/scripts/budulinek.10.md' => scriptV1,
            _ => throw StateError(a),
          },
          listBundledAssets: () async => {'assets/ambient/sea.opus', 'assets/scripts/budulinek.10.md'},
          docsDir: () async => tmp,
          client: client,
          remoteUrl: Uri.parse('https://example.test/c/catalog.json'),
          drafts: drafts,
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

    test('updated script is downloaded and loadable', () async {
      final v2 = miniJson(version: 2, script: scriptV2);
      final client = MockClient((req) async => switch (req.url.path) {
            '/c/catalog.json' => http.Response.bytes(utf8.encode(jsonEncode(v2)), 200),
            '/c/scripts/budulinek.10.md' => http.Response.bytes(utf8.encode(scriptV2), 200),
            _ => http.Response('', 404),
          });
      final r = repo(client);
      final snap = await r.init();
      final before = snap.local.resolve(snap.catalog.tale('budulinek')!.script())!;
      expect(before, const AssetRef('assets/scripts/budulinek.10.md'));
      expect(await r.loadText(before), scriptV1);

      final (_, next) = await r.sync(snap);
      final after = next.local.resolve(next.catalog.tale('budulinek')!.script())!;
      expect(after, isA<FileRef>());
      expect(await r.loadText(after), scriptV2);
    });

    test('a schema-1 remote catalog leaves everything as is', () async {
      final old = {...miniJson(version: 5), 'schema': 1};
      final client = MockClient((_) async => http.Response.bytes(utf8.encode(jsonEncode(old)), 200));
      final r = repo(client);
      final snap = await r.init();
      final (result, next) = await r.sync(snap);
      expect(result, SyncResult.upToDate);
      expect(next.catalog.version, 1);
    });

    test('INCLUDE_DRAFTS=false hides bundled draft tales', () async {
      final client = MockClient((_) async => http.Response('', 404));
      expect((await repo(client).init()).catalog.tales, hasLength(1));
      expect((await repo(client, drafts: false).init()).catalog.tales, isEmpty);
    });
  });
}
