import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajanek/core/db/database.dart';
import 'package:hajanek/core/providers.dart';
import 'package:hajanek/features/catalog/catalog_controller.dart';
import 'package:hajanek/features/catalog/catalog_models.dart';
import 'package:hajanek/features/catalog/catalog_repository.dart';
import 'package:hajanek/features/catalog/catalog_sync.dart';
import 'package:hajanek/features/player/player_controller.dart';
import 'package:hajanek/features/settings/settings_controller.dart';
import 'package:hajanek/features/voice/recording_text.dart';
import 'package:hajanek/features/voice/voice_api.dart';
import 'package:hajanek/features/voice/voice_controller.dart';

/// Minimal stand-in for hajanek-api (CONTRACTS §6) on localhost.
class FakeApi {
  late HttpServer server;
  final requests = <String>[];
  final uploads = <Map<String, String>>[];
  var voiceStatus = 'pending';
  final renders = <String>[];
  final clips = <String, List<int>>{};

  /// Bytes the manifest claims (to simulate a truncated download).
  final claimed = <String, int>{};

  Uri get url => Uri.parse('http://${server.address.host}:${server.port}');

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(_handle);
  }

  Future<void> _handle(HttpRequest req) async {
    final path = req.uri.path;
    requests.add('${req.method} $path');
    final res = req.response;
    Future<void> json(Object body, [int status = 200]) async {
      res
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await res.close();
    }

    if (req.method == 'POST' && path == '/v1/devices') {
      return json({'device_id': 'd1', 'token': 'tok-1'}, 201);
    }
    if (req.headers.value('authorization') != 'Bearer tok-1') return json({'error': 'auth'}, 401);

    if (req.method == 'POST' && path == '/v1/voices') {
      final body = latin1.decode(await req.fold<List<int>>([], (a, b) => a..addAll(b)));
      final fields = <String, String>{};
      for (final m in RegExp(r'name="(\w+)"(?:; filename="[^"]*")?\r\n(?:[^\r\n]*\r\n)*?\r\n([^\r]*)')
          .allMatches(body)) {
        fields[m.group(1)!] = m.group(2)!;
      }
      uploads.add(fields);
      return json({
        'voice': {'id': 'v1', 'name': fields['name'], 'status': 'pending', 'created_at': 'x'},
      }, 201);
    }
    if (req.method == 'GET' && path == '/v1/voices/v1') {
      return json({'id': 'v1', 'name': 'Jana', 'status': voiceStatus});
    }
    if (req.method == 'DELETE' && path == '/v1/voices/v1') return json({'ok': true});
    if (req.method == 'POST' && path == '/v1/voices/v1/renders') {
      final b = jsonDecode(await utf8.decodeStream(req)) as Map<String, dynamic>;
      renders.add('${b['tale']}/${b['length_min']}');
      return json({'render': {'status': 'queued'}});
    }
    final m = RegExp(r'^/v1/voices/v1/renders/([\w-]+)/10$').firstMatch(path);
    if (req.method == 'GET' && m != null) {
      if (m.group(1) != 'budulinek') return json({'error': 'none'}, 404);
      return json({
        'status': 'running',
        'script_sha256': 'x' * 64,
        'done': clips.length,
        'total': 3,
        'clips': {
          for (final e in clips.entries)
            e.key: {
              'url': '/v1/clips/v1/${e.key}.m4a',
              'duration_s': 1.5,
              'bytes': claimed[e.key] ?? e.value.length,
            },
        },
      });
    }
    final c = RegExp(r'^/v1/clips/v1/(\w+)\.m4a$').firstMatch(path);
    if (req.method == 'GET' && c != null) {
      res.add(clips[c.group(1)]!);
      await res.close();
      return;
    }
    return json({'error': 'not found'}, 404);
  }
}

Catalog miniCatalog() => Catalog.fromJson({
      'schema': 2,
      'version': 1,
      'base_url': 'https://example.test/',
      'tales': [
        for (final id in ['budulinek', 'snehurka'])
          {
            'id': id,
            'title': id,
            'free': id == 'budulinek',
            'scripts': [
              {'length_min': 10, 'path': 'scripts/$id.10.md', 'sha256': 'a' * 64, 'bytes': 1},
            ],
          },
      ],
      'ambient': [],
      'presets': [],
    });

void main() {
  late FakeApi fake;
  late Directory tmp;
  setUp(() async {
    fake = FakeApi();
    await fake.start();
    tmp = Directory.systemTemp.createTempSync('hajanek-voice');
  });
  tearDown(() async {
    await fake.server.close(force: true);
    tmp.deleteSync(recursive: true);
  });

  VoiceApi api([TokenStore? tokens]) => VoiceApi(tokens: tokens ?? MemoryTokenStore(), baseUrl: fake.url);

  test('registers the device once and keeps the token', () async {
    final tokens = MemoryTokenStore();
    final a = api(tokens);
    expect(await a.ensureDevice(), 'tok-1');
    expect(await a.ensureDevice(), 'tok-1');
    expect(tokens.token, 'tok-1');
    expect(fake.requests.where((r) => r == 'POST /v1/devices'), hasLength(1));
  });

  test('uploads the sample with name and consent', () async {
    final sample = File('${tmp.path}/s.m4a')..writeAsBytesSync(List.filled(64, 7));
    final v = await api().createVoice(
      samplePath: sample.path,
      name: 'Jana',
      consentText: 'Jsem Jana a souhlasím.',
    );
    expect(v.id, 'v1');
    expect(v.status, VoiceStatus.pending);
    final f = fake.uploads.single;
    expect(f['name'], 'Jana');
    expect(f['consent'], 'true');
    expect(utf8.decode(latin1.encode(f['consent_text']!)), 'Jsem Jana a souhlasím.');
    expect(f.containsKey('sample'), isTrue);
  });

  test('status poll, render request, manifest and clip download', () async {
    final a = api();
    expect((await a.getVoice('v1')).status, VoiceStatus.pending);
    fake.voiceStatus = 'ready';
    expect((await a.getVoice('v1')).status, VoiceStatus.ready);

    await a.requestRender('v1', 'budulinek', 10);
    expect(fake.renders, ['budulinek/10']);
    expect(await a.manifest('v1', 'snehurka', 10), isNull);

    fake.clips['k1'] = [1, 2, 3];
    fake.clips['k2'] = [4, 5];
    final m = (await a.manifest('v1', 'budulinek', 10))!;
    expect(m.total, 3);
    expect(m.clips.keys, ['k1', 'k2']);

    final plan = planClipDownloads([m, m], {'k1': 3});
    expect(plan.map((p) => p.$1), ['k2']);
    await a.downloadClip(plan.single.$2, '${tmp.path}/k2.m4a');
    expect(File('${tmp.path}/k2.m4a').readAsBytesSync(), [4, 5]);
    expect(File('${tmp.path}/k2.m4a.part').existsSync(), isFalse);
    expect(clipProgress([m], {'k1', 'k2'}), (2, 3));
  });

  test('a short download is rejected and leaves nothing behind', () async {
    fake.clips['k1'] = [1, 2, 3];
    fake.claimed['k1'] = 10;
    final m = (await api().manifest('v1', 'budulinek', 10))!;
    await expectLater(
      api().downloadClip(m.clips['k1']!, '${tmp.path}/k1.m4a'),
      throwsA(isA<VoiceApiException>()),
    );
    expect(tmp.listSync(), isEmpty);
  });

  test('offline gives a calm Czech message', () async {
    final a = api();
    await fake.server.close(force: true);
    final e = await a.getVoice('v1').then<Object?>((_) => null, onError: (Object e) => e);
    expect(e, isA<VoiceApiException>());
    expect((e! as VoiceApiException).message, msgOffline);
  });

  test('controller: pending → ready → renders for free tales → clips on disk', () async {
    fake.clips['k1'] = [1, 2, 3];
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      initialCatalogProvider.overrideWithValue(CatalogSnapshot(
        catalog: miniCatalog(),
        local: const LocalContent(bundled: {}, blobs: {}, blobDir: '/'),
      )),
      voiceApiProvider.overrideWithValue(api()),
      voicesDirProvider.overrideWithValue(tmp.path),
    ]);
    addTearDown(c.dispose);
    final ctrl = c.read(voiceProvider.notifier);

    final sample = File('${tmp.path}/s.m4a')..writeAsBytesSync([0]);
    await ctrl.upload(samplePath: sample.path, name: 'Jana', consentText: 'x');
    expect(c.read(settingsProvider).voiceId, 'v1');

    await ctrl.refresh();
    expect(c.read(voiceProvider).voices.single.status, VoiceStatus.pending);
    expect(fake.renders, isEmpty);

    fake.voiceStatus = 'ready';
    await ctrl.refresh();
    final v = c.read(voiceProvider).voices.single;
    expect(fake.renders, ['budulinek/10']); // free tales only
    expect(File('${tmp.path}/v1/k1.m4a').readAsBytesSync(), [1, 2, 3]);
    expect((v.done, v.total), (1, 3));

    // Same script sha: no second render request.
    await ctrl.refresh();
    expect(fake.renders, hasLength(1));
    final stored = LocalVoice.decodeList((await db.readAllValues())[parentVoicesKey]);
    expect(stored.single.requested, {'budulinek': 'a' * 64});

    await ctrl.delete('v1');
    expect(c.read(voiceProvider).voices, isEmpty);
    expect(Directory('${tmp.path}/v1').existsSync(), isFalse);
    expect(c.read(settingsProvider).voiceId, 'system');
  });

  test('recording text: consent first, name filled in, tips separate', () {
    final md = File('assets/voice/recording_script.md').readAsStringSync();
    final t = parseRecordingScript(md, name: ' Jana ');
    expect(t.consent, 'Jsem Jana a souhlasím, aby Hajánek z této nahrávky vytvořil můj hlas.');
    expect(t.lines, hasLength(6));
    expect(t.tips.first, startsWith('Najdi tichou místnost'));
    expect(parseRecordingScript(md, name: '').consent, startsWith('Jsem … a'));
  });
}
