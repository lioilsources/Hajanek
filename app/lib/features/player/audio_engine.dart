import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../../core/content_ref.dart';
import 'voice_source.dart';

/// Thin seam over the ambient players so the controller stays testable.
abstract interface class AudioEngine {
  static const layerSlots = 3;

  Future<void> setLayer(int slot, ContentRef? ref);
  void setLayerVolume(int slot, double v);
  void playAmbient();
  Future<void> pauseAmbient();
  Future<void> stopAll();
  Future<void> dispose();
}

/// Three looping ambient players mixed in-app.
class JustAudioEngine implements AudioEngine {
  final _layers = List.generate(AudioEngine.layerSlots, (_) => AudioPlayer());
  final _layerRefs = List<ContentRef?>.filled(AudioEngine.layerSlots, null);
  bool _ambientPlaying = false;

  AudioSource _source(ContentRef ref) => switch (ref) {
        AssetRef(:final asset) => AudioSource.asset(asset),
        FileRef(:final path) => AudioSource.file(path),
      };

  @override
  Future<void> setLayer(int slot, ContentRef? ref) async {
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
  void setLayerVolume(int slot, double v) => _layers[slot].setVolume(v.clamp(0.0, 1.0));

  // play() completes only when playback stops, so it's never awaited.
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
    await Future.wait(_layers.map((p) => p.stop()));
  }

  @override
  Future<void> dispose() async {
    for (final p in _layers) {
      await p.dispose();
    }
  }
}

/// Cloned-voice clips on their own player, next to the ambient layers.
class JustAudioClipOutput implements ClipOutput {
  JustAudioClipOutput() {
    _player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) _finish();
    });
  }

  final _player = AudioPlayer();
  Completer<void>? _current;

  @override
  Future<void> play(String path, double volume) async {
    _finish();
    final c = _current = Completer<void>();
    try {
      await _player.setFilePath(path);
      await _player.setVolume(volume.clamp(0.0, 1.0));
      if (!identical(_current, c)) return;
      unawaited(_player.play());
    } on Object {
      _finish();
    }
    return c.future;
  }

  @override
  void setVolume(double volume) => _player.setVolume(volume.clamp(0.0, 1.0));

  @override
  Future<void> stop() async {
    _finish();
    await _player.stop();
  }

  void _finish() {
    final c = _current;
    _current = null;
    if (c != null && !c.isCompleted) c.complete();
  }
}
