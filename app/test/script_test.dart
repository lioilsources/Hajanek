import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hajanek/core/script/script.dart';
import 'package:hajanek/core/script/tone.dart';

// Shared with the Go parser in forge/api; `flutter test` runs from app/.
final golden =
    jsonDecode(File('../docs/testdata/utterances.golden.json').readAsStringSync()) as Map<String, dynamic>;

Map<String, Object?> itemJson(ScriptItem i, String voiceId) => switch (i) {
      Utterance u => {
          'type': 'utterance',
          'section': u.section,
          'tone': u.tone.name,
          'text': u.canonicalText,
          'key': u.keyFor(voiceId),
        },
      ScriptPause p => {'type': 'pause', 'seconds': p.seconds},
    };

void main() {
  group('golden', () {
    test('items and keys match docs/testdata/utterances.golden.json', () {
      final voiceId = golden['voice_id'] as String;
      final script = parseScript(golden['script'] as String);
      final expected = [
        for (final e in golden['items'] as List)
          {
            for (final kv in (e as Map<String, dynamic>).entries)
              kv.key: kv.value is num && kv.key == 'seconds' ? (kv.value as num).toDouble() : kv.value,
          },
      ];
      expect([for (final i in script.items) itemJson(i, voiceId)], expected);
      expect(script.status, 'gold');
    });

    test('a vocative changes what is spoken, not the key', () {
      final script = parseScript(golden['script'] as String, vocative: '  Aničko ');
      final first = script.utterances.first;
      expect(first.text, 'Lehni si, Aničko.');
      expect(first.canonicalText, 'Lehni si, broučku.');
      expect(first.keyFor('test-voice'),
          '694c72c502825de681e10e363aa591226e2d4b8a15b630f564426ffe7c98321b');
    });
  });

  group('parser rules', () {
    test('NFC, whitespace collapse, tone reset per section, bare tone line', () {
      // "e" + combining caron must become "ě".
      final s = parseScript('## uvod\n[whisper]\nDobrě   ráno\t!\n## vstup\nA dál.\n');
      final u = s.utterances.toList();
      expect(u[0].text, 'Dobrě ráno !');
      expect(u[0].tone, Tone.whisper);
      expect(u[1].tone, Tone.soft);
    });

    test('multi-line comments and text before the first section are ignored', () {
      final s = parseScript('Úvodní řeč\n## uvod\n<!-- a\nb -->\nAhoj.\n[pause 0.5s]\n');
      expect(s.utterances.single.text, 'Ahoj.');
      expect((s.items.last as ScriptPause).duration, const Duration(milliseconds: 500));
    });

    test('rejects unknown or out-of-order sections and misplaced osloveni', () {
      expect(() => parseScript('## konec\nx\n'), throwsA(isA<ScriptFormatException>()));
      expect(() => parseScript('## vstup\nx\n## uvod\ny\n'), throwsA(isA<ScriptFormatException>()));
      expect(() => parseScript('## pribeh\n{{osloveni|ty}}\n'), throwsA(isA<ScriptFormatException>()));
    });

    test('estimate: 95 words per minute plus pauses', () {
      final words = List.filled(95, 'slovo').join(' ');
      final s = parseScript('## uvod\n$words\n[pause 10s]\n');
      expect(s.estimatedSeconds, closeTo(70, 1e-9));
    });

    test('every bundled script parses', () {
      final files = Directory('assets/scripts').listSync().whereType<File>().toList();
      expect(files, hasLength(10));
      for (final f in files) {
        final s = parseScript(f.readAsStringSync());
        expect(s.utterances, isNotEmpty, reason: f.path);
        expect({for (final u in s.utterances) u.section}, containsAll(scriptSections), reason: f.path);
      }
    });
  });

  group('tone', () {
    Utterance u(String section, Tone tone, int i, int n) => Utterance(
          section: section,
          tone: tone,
          text: 'x',
          canonicalText: 'x',
          indexInSection: i,
          sectionSize: n,
        );

    test('table values outside dojezd', () {
      expect(toneFor(u('pribeh', Tone.soft, 3, 10)), const ToneParams(rate: 0.85, volume: 1.0));
      expect(toneFor(u('uvod', Tone.slow, 0, 1)), const ToneParams(rate: 0.78, volume: 0.75));
      expect(toneFor(u('vstup', Tone.whisper, 0, 1)),
          const ToneParams(rate: 0.75, volume: 0.4, pitch: 0.95));
    });

    test('dojezd ramps linearly to 0.75× and 0.5 by position', () {
      final first = toneFor(u('dojezd', Tone.soft, 0, 5));
      final mid = toneFor(u('dojezd', Tone.soft, 2, 5));
      final last = toneFor(u('dojezd', Tone.soft, 4, 5));
      expect(first.rate, closeTo(0.85, 1e-9));
      expect(first.volume, closeTo(1.0, 1e-9));
      expect(mid.rate, closeTo(0.80, 1e-9));
      expect(mid.volume, closeTo(0.75, 1e-9));
      expect(last.rate, closeTo(0.75, 1e-9));
      expect(last.volume, closeTo(0.5, 1e-9));
    });

    test('dojezd never makes a whisper louder', () {
      final w = toneFor(u('dojezd', Tone.whisper, 4, 5));
      expect(w.volume, 0.4);
      expect(w.rate, 0.75);
      expect(w.pitch, 0.95);
    });

    test('platform rate mapping', () {
      expect(platformSpeechRate(1.0, ios: true), 0.5);
      expect(platformSpeechRate(0.85, ios: true), closeTo(0.425, 1e-9));
      expect(platformSpeechRate(0.85, ios: false), closeTo(0.85, 1e-9));
    });
  });
}
