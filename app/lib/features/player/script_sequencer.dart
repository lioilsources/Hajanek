// Walks a parsed script: utterances go to a VoiceSource, pauses are timers.
// Pure Dart (Timer + package:clock), so tests drive it with fake_async.

import 'dart:async';

import 'package:clock/clock.dart';

import '../../core/script/script.dart';
import '../../core/script/tone.dart';
import 'voice_source.dart';

class ScriptSequencer {
  ScriptSequencer({
    required this.items,
    required this.voice,
    this.onProgress,
    this.onCompleted,
    this.toneOf = toneFor,
  });

  final List<ScriptItem> items;
  final VoiceSource voice;

  /// Called after each finished item with the index of the next one.
  final void Function(int next)? onProgress;
  final void Function()? onCompleted;
  final ToneParams Function(Utterance) toneOf;

  int _index = 0;
  bool _running = false;
  bool _done = false;

  /// Bumped on pause/stop; a run loop of an older generation steps aside.
  int _gen = 0;

  /// Unfinished part of the current pause item.
  Duration? _pauseLeft;
  Timer? _timer;
  Completer<bool>? _wait;
  DateTime? _waitStarted;

  int get index => _index;
  int get length => items.length;
  bool get playing => _running;
  bool get done => _done;

  /// Section of the current (or last) utterance.
  String? get section {
    for (var i = _index.clamp(0, items.length - 1); i >= 0; i--) {
      final it = items[i];
      if (it is Utterance) return it.section;
    }
    for (final it in items) {
      if (it is Utterance) return it.section;
    }
    return null;
  }

  /// Starts, or resumes where it was paused. An utterance interrupted by
  /// [pause] is replayed from its beginning; a pause continues its rest.
  void play() {
    if (_running || _done) return;
    _running = true;
    unawaited(_run(++_gen));
  }

  Future<void> pause() async {
    if (!_running) return;
    _running = false;
    _gen++;
    _cancelWait();
    await voice.stop();
  }

  Future<void> stop() async {
    _done = true;
    _running = false;
    _gen++;
    _cancelWait();
    await voice.stop();
  }

  Future<void> _run(int gen) async {
    while (_index < items.length) {
      switch (items[_index]) {
        case final Utterance u:
          try {
            await voice.speak(u, toneOf(u));
          } on Object {
            // A broken utterance must not end the meditation.
          }
          if (gen != _gen) return;
        case final ScriptPause p:
          final finished = await _sleep(_pauseLeft ?? p.duration);
          if (gen != _gen || !finished) return;
          _pauseLeft = null;
      }
      _index++;
      onProgress?.call(_index);
    }
    _running = false;
    _done = true;
    onCompleted?.call();
  }

  Future<bool> _sleep(Duration d) {
    final c = _wait = Completer<bool>();
    _waitStarted = clock.now();
    _pauseLeft = d;
    _timer = Timer(d, () {
      if (!c.isCompleted) c.complete(true);
    });
    return c.future;
  }

  void _cancelWait() {
    final c = _wait;
    if (c == null || c.isCompleted) return;
    _timer?.cancel();
    final left = _pauseLeft! - clock.now().difference(_waitStarted!);
    _pauseLeft = left.isNegative ? Duration.zero : left;
    c.complete(false);
  }
}
