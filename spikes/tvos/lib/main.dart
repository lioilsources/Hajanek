// ADR-004 spike: does Hajanek's plugin set work on tvOS (flutter-tvos)?
// Runs every check on start, prints `SPIKE ...` / `TTS_PROBE ...` lines and
// shows them on screen (for `xcrun simctl io booted screenshot`).
import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart' hide Table;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

final lines = ValueNotifier<List<String>>([]);

void log(String s) {
  // ignore: avoid_print
  print(s);
  lines.value = [...lines.value, s];
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SpikeApp());
  unawaited(runAll());
}

Future<void> step(String name, Future<void> Function() body,
    {Duration timeout = const Duration(seconds: 30)}) async {
  try {
    await body().timeout(timeout);
  } catch (e) {
    log('SPIKE $name: FAIL ${e.toString().split('\n').first}');
  }
}

Future<void> runAll() async {
  // A suspended (backgrounded) app freezes the checks; wait to be resumed.
  while (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  log('SPIKE os=${Platform.operatingSystem} isIOS=${Platform.isIOS} '
      'version=${Platform.operatingSystemVersion}');
  await step('path_provider', () async {
    final d = await getApplicationSupportDirectory();
    log('SPIKE path_provider: OK $d');
  });
  await step('audio_session', () async {
    final s = await AudioSession.instance;
    await s.configure(const AudioSessionConfiguration.music());
    final ok = await s.setActive(true);
    log('SPIKE audio_session: OK configure(music) setActive=$ok');
  });
  for (final (name, loop) in [
    ('loop.opus', true),
    ('loop_opus.caf', true),
    ('loop_opus.mp4', true),
    ('loop.m4a', true),
    ('clip.m4a', false),
  ]) {
    await step('just_audio $name', () => playAsset(name, loop));
  }
  await step('drift', testDrift);
  await step('secure_storage', () async {
    const s = FlutterSecureStorage();
    await s.write(key: 'spike', value: 'hajanek-42');
    final v = await s.read(key: 'spike');
    log('SPIKE secure_storage: ${v == 'hajanek-42' ? 'OK' : 'FAIL'} read=$v');
  });
  await step('wakelock', () async {
    await WakelockPlus.enable();
    log('SPIKE wakelock: enabled=${await WakelockPlus.enabled}');
  });
  await step('audio_service', () async {
    final h = await AudioService.init(
      builder: _Handler.new,
      config: const AudioServiceConfig(
          androidNotificationChannelId: 'spike', androidNotificationChannelName: 'spike'),
    );
    log('SPIKE audio_service: OK init -> ${h.runtimeType}');
  }, timeout: const Duration(seconds: 10));
  await step('tts', ttsProbe, timeout: const Duration(seconds: 60));
  log('SPIKE done');
}

Future<void> playAsset(String name, bool loop) async {
  final p = AudioPlayer();
  try {
    final d = await p.setAsset('assets/$name').timeout(const Duration(seconds: 10));
    await p.setLoopMode(loop ? LoopMode.one : LoopMode.off);
    await p.setVolume(0.3);
    unawaited(p.play());
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    final pos = p.position;
    log('SPIKE just_audio $name: ${pos > const Duration(milliseconds: 500) ? 'OK' : 'FAIL'} '
        'duration=$d position=$pos state=${p.processingState.name}');
  } catch (e) {
    log('SPIKE just_audio $name: FAIL ${e.toString().split('\n').first}');
  } finally {
    await p.dispose();
  }
}

class _Db extends GeneratedDatabase {
  _Db(super.e);
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override
  int get schemaVersion => 1;
}

Future<void> testDrift() async {
  final db = _Db(driftDatabase(name: 'spike'));
  await db.customStatement('CREATE TABLE IF NOT EXISTS t (id INTEGER PRIMARY KEY, v TEXT)');
  await db.customStatement('INSERT INTO t (v) VALUES (?)', ['ahoj ${DateTime.now()}']);
  final rows = await db.customSelect('SELECT count(*) AS n, max(v) AS v, sqlite_version() AS sv FROM t').get();
  final r = rows.single.data;
  log('SPIKE drift: OK rows=${r['n']} last=${r['v']} sqlite=${r['sv']}');
  await db.close();
}

class _Handler extends BaseAudioHandler {}

// --- TTS probe: same logic as app/integration_test/tts_probe_test.dart ---

void _out(String s) => log('TTS_PROBE $s');

bool _isCzech(Map<String, String> v) {
  final l = (v['locale'] ?? '').toLowerCase().replaceAll('_', '-');
  return l == 'cs' || l.startsWith('cs-');
}

int _qualityRank(String? q) => switch (q) {
      'premium' || 'very high' => 5,
      'enhanced' || 'high' => 4,
      'normal' || 'default' => 3,
      'low' => 2,
      'very low' => 1,
      _ => 0,
    };

Map<String, String>? pickCzechVoice(Iterable<Map<String, String>> voices) {
  Map<String, String>? best;
  var bestScore = -1;
  for (final v in voices.where(_isCzech)) {
    final score = (v['network_required'] == '1' ? 0 : 10) + _qualityRank(v['quality']);
    if (score > bestScore) {
      best = v;
      bestScore = score;
    }
  }
  return best;
}

Future<void> ttsProbe() async {
  _out('form_factor=${Platform.operatingSystem == 'tvos' ? 'tv' : 'phone'} (spike: by Platform.operatingSystem)');
  final tts = FlutterTts();
  final raw = await tts.getVoices as List? ?? const [];
  final voices = [
    for (final v in raw)
      if (v is Map) {for (final e in v.entries) '${e.key}': '${e.value}'},
  ];
  _out('voices_total=${voices.length}');
  final langs = (await tts.getLanguages as List? ?? const []).map((l) => '$l').toList()..sort();
  _out('cs_language=${langs.any((l) => l.toLowerCase().startsWith('cs'))} languages=${langs.length}');
  for (final v in voices) {
    if ((v['locale'] ?? '').toLowerCase().startsWith('cs')) _out('cs_voice $v');
  }
  final picked = pickCzechVoice(voices);
  _out('picked=$picked');
  if (picked == null) return;
  final done = Completer<String>();
  tts
    ..setCompletionHandler(() => done.complete('completed'))
    ..setErrorHandler((m) => done.complete('error $m'));
  await tts.setLanguage('cs-CZ');
  await tts.setVoice({'name': picked['name'] ?? '', 'locale': picked['locale'] ?? 'cs-CZ'});
  final sw = Stopwatch()..start();
  await tts.speak('Byla jednou jedna holčička, které se říkalo Červená Karkulka.');
  final r = await done.future.timeout(const Duration(seconds: 20), onTimeout: () => 'timeout');
  _out('speak=$r in ${sw.elapsedMilliseconds} ms');
}

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF14121C),
          body: Padding(
            padding: const EdgeInsets.all(48),
            child: ValueListenableBuilder(
              valueListenable: lines,
              builder: (_, l, _) => ListView(
                children: [
                  for (final s in l)
                    Text(s,
                        style: TextStyle(
                            fontSize: 18,
                            color: s.contains('FAIL') ? Colors.redAccent : Colors.white)),
                ],
              ),
            ),
          ),
        ),
      );
}
