// Pure Dart sleep timer. Wall-clock based: keeps counting while paused.

enum SleepTimerKind { off, minutes, endOfTale }

class SleepTimerOption {
  const SleepTimerOption._(this.kind, [this.minutes = 0]);
  const SleepTimerOption.off() : this._(SleepTimerKind.off);
  const SleepTimerOption.endOfTale() : this._(SleepTimerKind.endOfTale);
  const SleepTimerOption.minutes(int m) : this._(SleepTimerKind.minutes, m);

  final SleepTimerKind kind;
  final int minutes;

  static const choices = <SleepTimerOption>[
    SleepTimerOption.off(),
    SleepTimerOption.minutes(5),
    SleepTimerOption.minutes(10),
    SleepTimerOption.minutes(20),
    SleepTimerOption.minutes(30),
    SleepTimerOption.minutes(45),
    SleepTimerOption.minutes(60),
    SleepTimerOption.endOfTale(),
  ];

  /// Stable int for storage: 0 off, -1 end of tale, else minutes.
  int get code => switch (kind) {
        SleepTimerKind.off => 0,
        SleepTimerKind.endOfTale => -1,
        SleepTimerKind.minutes => minutes,
      };

  static SleepTimerOption fromCode(int code) => switch (code) {
        0 => const SleepTimerOption.off(),
        -1 => const SleepTimerOption.endOfTale(),
        > 0 => SleepTimerOption.minutes(code),
        _ => const SleepTimerOption.off(),
      };

  @override
  bool operator ==(Object other) => other is SleepTimerOption && other.code == code;
  @override
  int get hashCode => code;
}

class SleepTimer {
  SleepTimer(this.option, {this.fade = const Duration(seconds: 60)});

  final SleepTimerOption option;
  final Duration fade;
  DateTime? _deadline;

  DateTime? get deadline => _deadline;

  void start(DateTime now) {
    if (option.kind == SleepTimerKind.minutes) {
      _deadline = now.add(Duration(minutes: option.minutes));
    }
  }

  /// "Po dohrání": the fade starts when the tale's voice track ends.
  void taleFinished(DateTime now) {
    if (option.kind == SleepTimerKind.endOfTale && _deadline == null) {
      _deadline = now.add(fade);
    }
  }

  Duration? remaining(DateTime now) {
    final d = _deadline;
    if (d == null) return null;
    final r = d.difference(now);
    return r.isNegative ? Duration.zero : r;
  }

  bool isExpired(DateTime now) {
    final d = _deadline;
    return d != null && !now.isBefore(d);
  }

  /// Master gain 1 → 0 over the last [fade] before the deadline.
  double gain(DateTime now) {
    final r = remaining(now);
    if (r == null) return 1;
    if (r >= fade) return 1;
    if (fade == Duration.zero) return r > Duration.zero ? 1 : 0;
    return r.inMicroseconds / fade.inMicroseconds;
  }
}
