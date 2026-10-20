import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/strings.dart';
import '../catalog/catalog_controller.dart';
import '../catalog/catalog_models.dart';
import '../settings/settings_controller.dart';
import '../timer/sleep_timer.dart';
import 'audio_engine.dart';
import 'audio_handler.dart';
import 'ritual.dart';

enum SessionKind { tale, mixer }

class PlayerState {
  const PlayerState({
    this.kind,
    this.tale,
    this.voice,
    this.layers = const [],
    this.balance = 0.5,
    this.playing = false,
    this.phase = RitualPhase.idle,
    this.timer = const SleepTimerOption.off(),
    this.timerRemaining,
    this.position = Duration.zero,
    this.duration,
  });

  final SessionKind? kind;
  final Tale? tale;
  final String? voice;
  final List<MixLayer> layers;
  final double balance;
  final bool playing;
  final RitualPhase phase;
  final SleepTimerOption timer;
  final Duration? timerRemaining;
  final Duration position;
  final Duration? duration;

  bool get active => kind != null;
  String get title => tale?.title ?? S.mixerTitle;

  PlayerState copyWith({
    List<MixLayer>? layers,
    double? balance,
    bool? playing,
    RitualPhase? phase,
    SleepTimerOption? timer,
    Duration? Function()? timerRemaining,
    Duration? position,
    Duration? Function()? duration,
  }) =>
      PlayerState(
        kind: kind,
        tale: tale,
        voice: voice,
        layers: layers ?? this.layers,
        balance: balance ?? this.balance,
        playing: playing ?? this.playing,
        phase: phase ?? this.phase,
        timer: timer ?? this.timer,
        timerRemaining: timerRemaining == null ? this.timerRemaining : timerRemaining(),
        position: position ?? this.position,
        duration: duration == null ? this.duration : duration(),
      );
}

/// Overridden in main(); null in widget tests (no platform audio).
final audioEngineProvider = Provider<AudioEngine?>((ref) => null);
final audioHandlerProvider = Provider<HajanekAudioHandler?>((ref) => null);

final playerProvider = NotifierProvider<PlayerController, PlayerState>(PlayerController.new);

/// Volume multipliers for a balance slider value b in 0..1.
({double voice, double background}) balanceGains(double b) => (
      voice: math.min(1.0, 2 * (1 - b)),
      background: math.min(1.0, 2 * b),
    );

class PlayerController extends Notifier<PlayerState> {
  static const tickEvery = Duration(milliseconds: 250);

  AudioEngine? get _engine => ref.read(audioEngineProvider);
  DateTime _now() => ref.read(clockProvider)();

  RitualMachine? _ritual;
  SleepTimer _timer = SleepTimer(const SleepTimerOption.off());
  Timer? _ticker;
  bool _voiceStarted = false;
  int? _historyId;
  final _subs = <StreamSubscription<Object?>>[];

  @override
  PlayerState build() {
    final s = ref.read(settingsProvider);
    final engine = _engine;
    if (engine != null) {
      _subs.add(engine.voiceCompleted.listen((_) => _onVoiceCompleted()));
      _subs.add(engine.voicePosition.listen(_onPosition));
    }
    final handler = ref.read(audioHandlerProvider);
    if (handler != null) {
      handler
        ..onPlay = resume
        ..onPause = pause
        ..onStop = stop;
    }
    ref.onDispose(() {
      _ticker?.cancel();
      for (final s in _subs) {
        s.cancel();
      }
    });
    return PlayerState(layers: s.lastMix, balance: s.balance, timer: s.timer);
  }

  Future<void> startTale({
    required Tale tale,
    required String voice,
    required List<MixLayer> layers,
    required bool ritual,
  }) async {
    final track = tale.track(voice);
    final source = track == null ? null : ref.read(catalogProvider).resolve(track);
    if (source == null) return;
    await stop();
    final now = _now();
    await _engine?.setVoice(source);
    _ritual = RitualMachine(ref.read(settingsProvider).ritualConfig(enabled: ritual))..start(now);
    _timer = SleepTimer(state.timer)..start(now);
    _voiceStarted = false;
    state = PlayerState(
      kind: SessionKind.tale,
      tale: tale,
      voice: voice,
      layers: layers,
      balance: state.balance,
      playing: true,
      phase: _ritual!.phase,
      timer: state.timer,
      duration: Duration(milliseconds: (track!.durationS * 1000).round()),
    );
    await _applyLayers();
    _engine?.playAmbient();
    _startTicker();
  }

  /// Standalone jukebox: just the ambient layers.
  Future<void> startMixer() async {
    if (state.active) return resume();
    final now = _now();
    _ritual = null;
    _timer = SleepTimer(
      state.timer.kind == SleepTimerKind.endOfTale ? const SleepTimerOption.off() : state.timer,
    )..start(now);
    state = PlayerState(
      kind: SessionKind.mixer,
      layers: state.layers,
      balance: state.balance,
      playing: true,
      timer: _timer.option,
    );
    await _applyLayers();
    _engine?.playAmbient();
    _startTicker();
  }

  Future<void> pause() async {
    if (!state.active || !state.playing) return;
    _ritual?.pause(_now());
    state = state.copyWith(playing: false);
    await _engine?.pauseVoice();
    await _engine?.pauseAmbient();
    _publish();
  }

  Future<void> resume() async {
    if (!state.active || state.playing) return;
    _ritual?.resume(_now());
    state = state.copyWith(playing: true);
    _engine?.playAmbient();
    if (_voiceStarted && _ritual?.phase == RitualPhase.voice) _engine?.playVoice();
    _tick();
  }

  Future<void> togglePlay() => state.playing ? pause() : resume();

  Future<void> stop() async {
    _ticker?.cancel();
    _ticker = null;
    _ritual = null;
    _voiceStarted = false;
    final wasActive = state.active;
    state = PlayerState(layers: state.layers, balance: state.balance, timer: state.timer);
    if (wasActive) await _engine?.stopAll();
    _publish();
  }

  void setLayers(List<MixLayer> layers) {
    final l = layers.take(maxMixLayers).toList();
    state = state.copyWith(layers: l);
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(lastMix: l));
    if (state.active) {
      _applyLayers();
    }
  }

  void setBalance(double b) {
    state = state.copyWith(balance: b.clamp(0.0, 1.0));
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(balance: state.balance));
    _tick();
  }

  void setTimer(SleepTimerOption option) {
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(timer: option));
    final now = _now();
    _timer = SleepTimer(option)..start(now);
    final phase = _ritual?.phase;
    if (phase == RitualPhase.tail || phase == RitualPhase.fadeOut) _timer.taleFinished(now);
    state = state.copyWith(timer: option, timerRemaining: () => _timer.remaining(now));
    _tick();
  }

  Future<void> _applyLayers() async {
    final catalog = ref.read(catalogProvider);
    for (var i = 0; i < AudioEngine.layerSlots; i++) {
      final ambient = i < state.layers.length ? catalog.ambientRef(state.layers[i].ambient) : null;
      await _engine?.setLayer(i, ambient);
    }
    _tick();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(tickEvery, (_) => _tick());
    _tick();
  }

  void _tick() {
    if (!state.active) return;
    final now = _now();
    if (_timer.isExpired(now)) {
      stop();
      return;
    }
    var ambientGain = 1.0;
    var phase = state.phase;
    final ritual = _ritual;
    if (ritual != null) {
      final frame = ritual.tick(now);
      phase = frame.phase;
      if (frame.phase == RitualPhase.done) {
        stop();
        return;
      }
      if (frame.voiceActive && !_voiceStarted && state.playing) {
        _voiceStarted = true;
        _engine?.playVoice();
        _recordStart(now);
      }
      ambientGain = frame.ambientGain;
    }

    final master = _timer.gain(now);
    final g = balanceGains(state.balance);
    final engine = _engine;
    if (engine != null) {
      engine.setVoiceVolume(g.voice * master);
      for (var i = 0; i < AudioEngine.layerSlots; i++) {
        final v = i < state.layers.length ? state.layers[i].volume : 0.0;
        engine.setLayerVolume(i, v * g.background * ambientGain * master);
      }
    }

    final remaining = _timer.remaining(now);
    if (phase != state.phase || remaining?.inSeconds != state.timerRemaining?.inSeconds) {
      state = state.copyWith(phase: phase, timerRemaining: () => remaining);
    }
    _publish();
  }

  void _onVoiceCompleted() {
    if (state.kind != SessionKind.tale) return;
    final now = _now();
    _ritual?.voiceCompleted(now);
    _timer.taleFinished(now);
    final id = _historyId;
    if (id != null) {
      ref.read(databaseProvider).finishHistory(id, now);
      _historyId = null;
    }
    _tick();
  }

  void _onPosition(Duration p) {
    if (p.inSeconds != state.position.inSeconds && state.active) {
      final d = _engine?.voiceDuration;
      state = state.copyWith(position: p, duration: d == null ? null : () => d);
    }
  }

  Future<void> _recordStart(DateTime now) async {
    final tale = state.tale;
    final voice = state.voice;
    if (tale == null || voice == null) return;
    try {
      _historyId = await ref.read(databaseProvider).startHistory(tale.id, voice, now);
    } on Object {
      _historyId = null;
    }
  }

  bool? _lastPublishedPlaying;
  String? _lastPublishedTitle;

  void _publish() {
    final handler = ref.read(audioHandlerProvider);
    if (handler == null) return;
    if (_lastPublishedPlaying == state.playing &&
        _lastPublishedTitle == (state.active ? state.title : null)) {
      return;
    }
    _lastPublishedPlaying = state.playing;
    _lastPublishedTitle = state.active ? state.title : null;
    handler.show(
      title: state.title,
      playing: state.playing,
      active: state.active,
      duration: state.duration,
    );
  }
}
