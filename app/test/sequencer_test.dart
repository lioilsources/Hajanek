import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajanek/core/script/script.dart';
import 'package:hajanek/core/script/tone.dart';
import 'package:hajanek/features/player/script_sequencer.dart';
import 'package:hajanek/features/player/voice_source.dart';

/// Every utterance takes [length] of fake time unless stopped.
class FakeVoice implements VoiceSource {
  FakeVoice({this.length = const Duration(seconds: 2)});
  final Duration length;
  final spoken = <String>[];
  final finished = <String>[];
  final tones = <ToneParams>[];
  var stops = 0;
  double gain = 1;
  Completer<void>? _c;
  Timer? _t;

  @override
  Future<void> speak(Utterance u, ToneParams tone) {
    spoken.add(u.text);
    tones.add(tone);
    final c = _c = Completer<void>();
    _t = Timer(length, () {
      finished.add(u.text);
      if (!c.isCompleted) c.complete();
    });
    return c.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    _t?.cancel();
    final c = _c;
    if (c != null && !c.isCompleted) c.complete();
  }

  @override
  void setGain(double g) => gain = g;
}

class FakeClips implements ClipOutput {
  final played = <String>[];
  final volumes = <double>[];
  @override
  Future<void> play(String path, double volume) async {
    played.add(path);
    volumes.add(volume);
  }

  @override
  void setVolume(double volume) => volumes.add(volume);
  @override
  Future<void> stop() async {}
}

final script = parseScript('''
## uvod
Jedna.
[pause 10s]
Dvě.
## dojezd
[whisper] Tři.
''');

void main() {
  test('plays utterances and pauses in order, reports progress, completes', () {
    fakeAsync((async) {
      final voice = FakeVoice();
      final progress = <int>[];
      var completed = false;
      final seq = ScriptSequencer(
        items: script.items,
        voice: voice,
        onProgress: progress.add,
        onCompleted: () => completed = true,
      )..play();

      async.elapse(const Duration(seconds: 1));
      expect(voice.spoken, ['Jedna.']);
      expect(seq.section, 'uvod');

      async.elapse(const Duration(seconds: 1)); // Jedna done → pause starts
      expect(progress, [1]);
      async.elapse(const Duration(seconds: 9));
      expect(voice.spoken, ['Jedna.']);
      async.elapse(const Duration(seconds: 1)); // pause over
      expect(voice.spoken, ['Jedna.', 'Dvě.']);

      async.elapse(const Duration(seconds: 2));
      expect(seq.section, 'dojezd');
      async.elapse(const Duration(seconds: 2));
      expect(completed, isTrue);
      expect(seq.done, isTrue);
      expect(progress, [1, 2, 3, 4]);
      expect(voice.tones.last, toneFor(script.utterances.last));
    });
  });

  test('pause mid-utterance stops the voice; resume replays that utterance', () {
    fakeAsync((async) {
      final voice = FakeVoice();
      final seq = ScriptSequencer(items: script.items, voice: voice)..play();
      async.elapse(const Duration(seconds: 1));
      seq.pause();
      async.flushMicrotasks();
      expect(voice.stops, 1);
      expect(seq.playing, isFalse);

      async.elapse(const Duration(minutes: 5));
      expect(voice.spoken, ['Jedna.']);
      expect(voice.finished, isEmpty);

      seq.play();
      async.elapse(Duration.zero);
      expect(voice.spoken, ['Jedna.', 'Jedna.']);
      async.elapse(const Duration(seconds: 2));
      expect(voice.finished, ['Jedna.']);
      expect(seq.index, 1);
    });
  });

  test('pause during a pause keeps the remaining silence', () {
    fakeAsync((async) {
      final voice = FakeVoice();
      final seq = ScriptSequencer(items: script.items, voice: voice)..play();
      async.elapse(const Duration(seconds: 2 + 4)); // 4 s into the 10 s pause
      seq.pause();
      async.elapse(const Duration(minutes: 1));
      seq.play();
      async.elapse(const Duration(seconds: 5));
      expect(voice.spoken, ['Jedna.']);
      async.elapse(const Duration(seconds: 1));
      expect(voice.spoken, ['Jedna.', 'Dvě.']);
    });
  });

  test('stop ends it for good', () {
    fakeAsync((async) {
      final voice = FakeVoice();
      var completed = false;
      final seq = ScriptSequencer(items: script.items, voice: voice, onCompleted: () => completed = true)
        ..play();
      async.elapse(const Duration(seconds: 1));
      seq.stop();
      async.elapse(const Duration(minutes: 1));
      seq.play();
      async.elapse(const Duration(minutes: 1));
      expect(voice.spoken, ['Jedna.']);
      expect(completed, isFalse);
      expect(seq.done, isTrue);
    });
  });

  test('a throwing voice skips the utterance instead of ending the session', () {
    fakeAsync((async) {
      final seq = ScriptSequencer(items: script.items, voice: _ThrowingVoice())..play();
      async.elapse(const Duration(seconds: 11));
      expect(seq.done, isTrue);
    });
  });

  group('cloned voice', () {
    final u = script.utterances.first;

    test('plays the clip at tone volume × gain', () async {
      final clips = FakeClips();
      final fallback = FakeVoice();
      final v = ClonedVoiceSource(
        voiceId: 'v1',
        clipDir: '/clips/v1',
        output: clips,
        fallback: fallback,
        exists: (_) => true,
      )..setGain(0.5);
      await v.speak(u, const ToneParams(rate: 0.85, volume: 0.8));
      expect(clips.played, ['/clips/v1/${u.keyFor('v1')}.m4a']);
      expect(clips.volumes.last, closeTo(0.4, 1e-9));
      expect(fallback.spoken, isEmpty);
    });

    test('missing clip falls back to the system voice', () {
      fakeAsync((async) {
        final clips = FakeClips();
        final fallback = FakeVoice();
        final v = ClonedVoiceSource(
          voiceId: 'v1',
          clipDir: '/clips/v1',
          output: clips,
          fallback: fallback,
          exists: (p) => !p.contains(u.keyFor('v1')),
        );
        final seq = ScriptSequencer(items: script.items, voice: v)..play();
        async.elapse(const Duration(seconds: 30));
        expect(fallback.spoken, ['Jedna.']);
        expect(clips.played, hasLength(2));
        expect(seq.done, isTrue);
      });
    });
  });
}

class _ThrowingVoice implements VoiceSource {
  @override
  Future<void> speak(Utterance u, ToneParams tone) => Future.error(StateError('tts'));
  @override
  Future<void> stop() async {}
  @override
  void setGain(double gain) {}
}
