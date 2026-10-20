import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/script/script.dart';
import '../../core/strings.dart';
import '../catalog/catalog_controller.dart';
import '../catalog/catalog_models.dart';
import '../settings/settings_controller.dart';
import '../timer/sleep_timer.dart';
import 'audio_engine.dart';
import 'audio_handler.dart';
import 'ritual.dart';
import 'script_sequencer.dart';
import 'system_tts.dart';
import 'voice_source.dart';

enum SessionKind { tale, mixer }

class PlayerState {
  const PlayerState({
    this.kind,
    this.tale,
    this.voiceId,
    this.layers = const [],
    this.balance = 0.5,
    this.playing = false,
    this.phase = RitualPhase.idle,
    this.timer = const SleepTimerOption.off(),
    this.timerRemaining,
    this.progress = 0,
    this.section,
  });

  final SessionKind? kind;
  final Tale? tale;
  final String? voiceId;
  final List<MixLayer> layers;
  final double balance;
  final bool playing;
  final RitualPhase phase;
  final SleepTimerOption timer;
  final Duration? timerRemaining;

  /// Share of the script already spoken, 0..1.
  final double progress;

  /// Script section being read (`uvod` … `dojezd`).
  final String? section;

  bool get active => kind != null;
  String get title => tale?.title ?? S.mixerTitle;

  PlayerState copyWith({
    List<MixLayer>? layers,
    double? balance,
    bool? playing,
    RitualPhase? phase,
    SleepTimerOption? timer,
    Duration? Function()? timerRemaining,
    double? progress,
    String? section,
  }) =>
      PlayerState(
        kind: kind,
        tale: tale,
        voiceId: voiceId,
        layers: layers ?? this.layers,
        balance: balance ?? this.balance,
        playing: playing ?? this.playing,
        phase: phase ?? this.phase,
        timer: timer ?? this.timer,
        timerRemaining: timerRemaining == null ? this.timerRemaining : timerRemaining(),
        progress: progress ?? this.progress,
        section: section ?? this.section,
      );
}

/// Overridden in main(); null in widget tests (no platform audio).
final audioEngineProvider = Provider<AudioEngine?>((ref) => null);
final audioHandlerProvider = Provider<HajanekAudioHandler?>((ref) => null);
final systemTtsProvider = Provider<SystemTtsSource?>((ref) => null);
final clipOutputProvider = Provider<ClipOutput?>((ref) => null);

/// `applicationSupport/voices`; clips of voice X live in `{dir}/X/`.
final voicesDirProvider = Provider<String?>((ref) => null);

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
  ScriptSequencer? _script;
  VoiceSource? _voice;
  SleepTimer _timer = SleepTimer(const SleepTimerOption.off());
  Timer? _ticker;
  bool _voiceStarted = false;
  int? _historyId;

  @override
  PlayerState build() {
    final s = ref.read(settingsProvider);
    final handler = ref.read(audioHandlerProvider);
    if (handler != null) {
      handler
        ..onPlay = resume
        ..onPause = pause
        ..onStop = stop;
    }
    ref.onDispose(() {
      _ticker?.cancel();
      _script?.stop();
    });
    return PlayerState(layers: s.lastMix, balance: s.balance, timer: s.timer);
  }

  VoiceSource _voiceFor(String voiceId) {
    final system = ref.read(systemTtsProvider) ?? SilentVoiceSource();
    final out = ref.read(clipOutputProvider);
    final dir = ref.read(voicesDirProvider);
    if (voiceId == systemVoiceId || out == null || dir == null) return system;
    return ClonedVoiceSource(voiceId: voiceId, clipDir: '$dir/$voiceId', output: out, fallback: system);
  }

  /// Returns false when the tale's script can't be loaded.
  Future<bool> startTale({
    required Tale tale,
    required List<MixLayer> layers,
    required bool ritual,
  }) async {
    final settings = ref.read(settingsProvider);
    final Script script;
    try {
      final text = await ref.read(catalogProvider.notifier).loadScript(tale.script());
      if (text == null) return false;
      script = parseScript(text, vocative: settings.vocative);
    } on Object {
      return false;
    }
    await stop();
    final now = _now();
    final voice = _voice = _voiceFor(settings.voiceId);
    final items = script.items;
    _script = ScriptSequencer(
      items: items,
      voice: voice,
      onProgress: (next) => _onScriptProgress(next, items.length),
      onCompleted: _onVoiceCompleted,
    );
    _ritual = RitualMachine(settings.ritualConfig(enabled: ritual))..start(now);
    _timer = SleepTimer(state.timer)..start(now);
    _voiceStarted = false;
    state = PlayerState(
      kind: SessionKind.tale,
      tale: tale,
      voiceId: settings.voiceId,
      layers: layers,
      balance: state.balance,
      playing: true,
      phase: _ritual!.phase,
      timer: state.timer,
      section: _script!.section,
    );
    await _applyLayers();
    _engine?.playAmbient();
    _startTicker();
    return true;
  }

  /// Standalone jukebox: just the ambient layers.
  Future<void> startMixer() async {
    if (state.active) return resume();
    final now = _now();
    _ritual = null;
    _script = null;
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
    await _script?.pause();
    await _engine?.pauseAmbient();
    _publish();
  }

  Future<void> resume() async {
    if (!state.active || state.playing) return;
    _ritual?.resume(_now());
    state = state.copyWith(playing: true);
    _engine?.playAmbient();
    if (_voiceStarted && _ritual?.phase == RitualPhase.voice) _script?.play();
    _tick();
  }

  Future<void> togglePlay() => state.playing ? pause() : resume();

  Future<void> stop() async {
    _ticker?.cancel();
    _ticker = null;
    _ritual = null;
    _voiceStarted = false;
    final script = _script;
    _script = null;
    _voice = null;
    final wasActive = state.active;
    state = PlayerState(layers: state.layers, balance: state.balance, timer: state.timer);
    await script?.stop();
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
        _script?.play();
        _recordStart(now);
      }
      ambientGain = frame.ambientGain;
    }

    final master = _timer.gain(now);
    final g = balanceGains(state.balance);
    _voice?.setGain(g.voice * master);
    final engine = _engine;
    if (engine != null) {
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

  void _onScriptProgress(int next, int total) {
    if (state.kind != SessionKind.tale) return;
    state = state.copyWith(
      progress: total == 0 ? 1 : next / total,
      section: _script?.section,
    );
    _publish();
  }

  Future<void> _recordStart(DateTime now) async {
    final tale = state.tale;
    final voice = state.voiceId;
    if (tale == null || voice == null) return;
    try {
      _historyId = await ref.read(databaseProvider).startHistory(tale.id, voice, now);
    } on Object {
      _historyId = null;
    }
  }

  String? _lastPublished;

  /// Lock screen: tale title, and the section while the voice reads.
  void _publish() {
    final handler = ref.read(audioHandlerProvider);
    if (handler == null) return;
    final subtitle = state.kind == SessionKind.tale && state.phase == RitualPhase.voice
        ? S.section(state.section)
        : null;
    final key = '${state.active}|${state.playing}|${state.title}|$subtitle';
    if (key == _lastPublished) return;
    _lastPublished = key;
    handler.show(
      title: state.title,
      subtitle: subtitle,
      playing: state.playing,
      active: state.active,
    );
  }
}
