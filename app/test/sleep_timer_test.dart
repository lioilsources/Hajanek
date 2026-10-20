import 'package:flutter_test/flutter_test.dart';
import 'package:hajanek/features/timer/sleep_timer.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 20, 20);

  test('off never expires', () {
    final t = SleepTimer(const SleepTimerOption.off())..start(t0);
    expect(t.remaining(t0), isNull);
    expect(t.gain(t0.add(const Duration(hours: 5))), 1);
    expect(t.isExpired(t0.add(const Duration(hours: 5))), isFalse);
  });

  test('minutes: full volume, then fades over the last minute', () {
    final t = SleepTimer(const SleepTimerOption.minutes(5))..start(t0);
    expect(t.remaining(t0), const Duration(minutes: 5));
    expect(t.gain(t0.add(const Duration(minutes: 4))), 1);
    expect(t.gain(t0.add(const Duration(minutes: 4, seconds: 30))), closeTo(0.5, 1e-9));
    expect(t.isExpired(t0.add(const Duration(minutes: 4, seconds: 59))), isFalse);
    expect(t.isExpired(t0.add(const Duration(minutes: 5))), isTrue);
    expect(t.gain(t0.add(const Duration(minutes: 6))), 0);
    expect(t.remaining(t0.add(const Duration(minutes: 6))), Duration.zero);
  });

  test('end of tale: waits for the tale, then fades', () {
    final t = SleepTimer(const SleepTimerOption.endOfTale())..start(t0);
    expect(t.isExpired(t0.add(const Duration(hours: 1))), isFalse);
    final end = t0.add(const Duration(minutes: 11));
    t.taleFinished(end);
    expect(t.gain(end), 1);
    expect(t.gain(end.add(const Duration(seconds: 45))), closeTo(0.25, 1e-9));
    expect(t.isExpired(end.add(const Duration(seconds: 60))), isTrue);
  });

  test('codes round-trip for every choice', () {
    for (final c in SleepTimerOption.choices) {
      expect(SleepTimerOption.fromCode(c.code), c);
    }
    expect(SleepTimerOption.choices.map((c) => c.code), [0, 5, 10, 20, 30, 45, 60, -1]);
  });
}
