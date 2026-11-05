// Which Czech system voices this device has (docs/HAJANEK_TV_PLAN.md §8
// step 1), and whether one actually speaks. Run on a TV box or emulator:
//   flutter test integration_test/tts_probe_test.dart -d <device>
// and copy the TTS_PROBE lines into ADR-004.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hajanek/core/form_factor.dart';
import 'package:hajanek/features/player/system_tts.dart';
import 'package:integration_test/integration_test.dart';

// ignore: avoid_print
void _out(String s) => print('TTS_PROBE $s');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('czech voices', (tester) async {
    _out('form_factor=${(await detectFormFactor()).name}');
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
      final l = (v['locale'] ?? '').toLowerCase();
      if (l.startsWith('cs')) _out('cs_voice $v');
    }
    final picked = pickCzechVoice(voices);
    _out('picked=$picked');
    if (picked == null) return;

    // Does it speak, and does the completion arrive (the sequencer needs it)?
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
  });
}
