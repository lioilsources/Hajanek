// Pure Dart state machine for the "dobrou noc" sequence (plan §4.3):
// ambient alone → meditation (ambient ducked) → ambient tail → fade-out → done.
// Time only advances through tick(now), so tests can drive it with a fake clock.

enum RitualPhase { idle, intro, voice, tail, fadeOut, done }

class RitualConfig {
  const RitualConfig({
    this.intro = const Duration(seconds: 60),
    this.tail = const Duration(minutes: 20),
    this.fade = const Duration(seconds: 60),
    this.duck = 0.6,
    this.duckRamp = const Duration(seconds: 3),
  });

  /// Ritual off: voice starts at once, ambient fades right after it ends.
  const RitualConfig.off({
    this.fade = const Duration(seconds: 60),
    this.duck = 0.6,
    this.duckRamp = const Duration(seconds: 3),
  })  : intro = Duration.zero,
        tail = Duration.zero;

  final Duration intro;
  final Duration tail;
  final Duration fade;

  /// Ambient multiplier while the voice plays.
  final double duck;
  final Duration duckRamp;
}

class RitualFrame {
  const RitualFrame(this.phase, this.ambientGain);
  final RitualPhase phase;

  /// Multiplier for every ambient layer (fade + ducking), 0..1.
  final double ambientGain;

  bool get voiceActive => phase == RitualPhase.voice;
}

class RitualMachine {
  RitualMachine(this.config);

  final RitualConfig config;
  RitualPhase _phase = RitualPhase.idle;
  Duration _inPhase = Duration.zero;
  DateTime? _last;
  bool _paused = false;

  RitualPhase get phase => _phase;
  Duration get inPhase => _inPhase;
  bool get paused => _paused;

  void start(DateTime now) {
    _last = now;
    _paused = false;
    _enter(config.intro > Duration.zero ? RitualPhase.intro : RitualPhase.voice);
  }

  void pause(DateTime now) {
    _advance(now);
    _paused = true;
  }

  void resume(DateTime now) {
    _last = now;
    _paused = false;
  }

  /// Time left before the voice starts; null outside the intro.
  Duration? get introRemaining => _phase == RitualPhase.intro ? config.intro - _inPhase : null;

  /// Parent tapped "start now": end the intro early.
  void skipIntro(DateTime now) {
    _advance(now);
    if (_phase == RitualPhase.intro) _enter(RitualPhase.voice);
  }

  /// The voice track reached its end.
  void voiceCompleted(DateTime now) {
    _advance(now);
    if (_phase == RitualPhase.voice) {
      _enter(config.tail > Duration.zero ? RitualPhase.tail : RitualPhase.fadeOut);
    }
  }

  RitualFrame tick(DateTime now) {
    _advance(now);
    // Carry overflow so a late tick can cross several phases correctly.
    while (true) {
      final limit = switch (_phase) {
        RitualPhase.intro => config.intro,
        RitualPhase.tail => config.tail,
        RitualPhase.fadeOut => config.fade,
        _ => null,
      };
      if (limit == null || _inPhase < limit) break;
      final overflow = _inPhase - limit;
      _enter(switch (_phase) {
        RitualPhase.intro => RitualPhase.voice,
        RitualPhase.tail => RitualPhase.fadeOut,
        _ => RitualPhase.done,
      });
      // Voice length is unknown here; it ends via voiceCompleted.
      _inPhase = _phase == RitualPhase.voice ? Duration.zero : overflow;
      if (_phase == RitualPhase.voice) break;
    }
    return RitualFrame(_phase, _ambientGain());
  }

  double _ambientGain() {
    double ramp(Duration d) => d == Duration.zero
        ? 1
        : (_inPhase.inMicroseconds / d.inMicroseconds).clamp(0.0, 1.0);
    final duck = config.duck;
    return switch (_phase) {
      RitualPhase.idle || RitualPhase.intro => 1,
      RitualPhase.voice => 1 - (1 - duck) * ramp(config.duckRamp),
      RitualPhase.tail => duck + (1 - duck) * ramp(config.duckRamp),
      // Ritual off: fade starts from the ducked level, no jump up.
      RitualPhase.fadeOut => (config.tail > Duration.zero ? 1.0 : duck) * (1 - ramp(config.fade)),
      RitualPhase.done => 0,
    };
  }

  void _enter(RitualPhase p) {
    _phase = p;
    _inPhase = Duration.zero;
  }

  void _advance(DateTime now) {
    final last = _last;
    _last = now;
    if (_paused || last == null || _phase == RitualPhase.idle || _phase == RitualPhase.done) return;
    final dt = now.difference(last);
    if (dt > Duration.zero) _inPhase += dt;
  }
}
