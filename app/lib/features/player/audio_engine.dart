import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../../core/audio_ref.dart';

/// Thin seam over the platform players so the controller stays testable.
abstract interface class AudioEngine {
  static const layerSlots = 3;

  Future<void> setVoice(AudioRef? ref);
  Future<void> setLayer(int slot, AudioRef? ref);
  void setVoiceVolume(double v);
  void setLayerVolume(int slot, double v);
  void playVoice();
  Future<void> pauseVoice();
  void playAmbient();
  Future<void> pauseAmbient();
  Future<void> stopAll();

  Stream<void> get voiceCompleted;
  Stream<Duration> get voicePosition;
  Duration? get voiceDuration;
  Future<void> dispose();
}

/// One voice player + three looping ambient players mixed in-app.
class JustAudioEngine implements AudioEngine {
  JustAudioEngine() {
    _voice.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) _completed.add(null);
    });
  }

  final _voice = AudioPlayer();
  final _layers = List.generate(AudioEngine.layerSlots, (_) => AudioPlayer());
  final _layerRefs = List<AudioRef?>.filled(AudioEngine.layerSlots, null);
  final _completed = StreamController<void>.broadcast();
  bool _ambientPlaying = false;

  AudioSource _source(AudioRef ref) => switch (ref) {
        AssetRef(:final asset) => AudioSource.asset(asset),
        FileRef(:final path) => AudioSource.file(path),
      };

  @override
  Future<void> setVoice(AudioRef? ref) async {
    await _voice.stop();
    if (ref != null) await _voice.setAudioSource(_source(ref));
  }

  @override
  Future<void> setLayer(int slot, AudioRef? ref) async {
    if (_layerRefs[slot] == ref) return;
    _layerRefs[slot] = ref;
    final p = _layers[slot];
    await p.stop();
    if (ref == null) return;
    await p.setAudioSource(_source(ref));
    await p.setLoopMode(LoopMode.one);
    if (_ambientPlaying) unawaited(p.play());
  }

  @override
  void setVoiceVolume(double v) => _voice.setVolume(v.clamp(0.0, 1.0));

  @override
  void setLayerVolume(int slot, double v) => _layers[slot].setVolume(v.clamp(0.0, 1.0));

  // play() completes only when playback stops, so it's never awaited.
  @override
  void playVoice() => unawaited(_voice.play());

  @override
  Future<void> pauseVoice() => _voice.pause();

  @override
  void playAmbient() {
    _ambientPlaying = true;
    for (var i = 0; i < _layers.length; i++) {
      if (_layerRefs[i] != null) unawaited(_layers[i].play());
    }
  }

  @override
  Future<void> pauseAmbient() async {
    _ambientPlaying = false;
    await Future.wait(_layers.map((p) => p.pause()));
  }

  @override
  Future<void> stopAll() async {
    _ambientPlaying = false;
    await Future.wait([_voice.stop(), ..._layers.map((p) => p.stop())]);
  }

  @override
  Stream<void> get voiceCompleted => _completed.stream;

  @override
  Stream<Duration> get voicePosition => _voice.positionStream;

  @override
  Duration? get voiceDuration => _voice.duration;

  @override
  Future<void> dispose() async {
    await _voice.dispose();
    for (final p in _layers) {
      await p.dispose();
    }
    await _completed.close();
  }
}
