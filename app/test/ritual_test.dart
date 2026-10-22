import 'package:flutter_test/flutter_test.dart';
import 'package:hajanek/features/player/player_controller.dart';
import 'package:hajanek/features/player/player_screen.dart';
import 'package:hajanek/features/player/ritual.dart';

class FakeClock {
  DateTime now = DateTime.utc(2026, 10, 20, 19, 30);
  void advance(Duration d) => now = now.add(d);
}

void main() {
  late FakeClock clock;
  setUp(() => clock = FakeClock());

  RitualFrame step(RitualMachine m, Duration d) {
    clock.advance(d);
    return m.tick(clock.now);
  }

  test('full ritual: intro → voice → tail → fade-out → done', () {
    final m = RitualMachine(const RitualConfig())..start(clock.now);
    expect(m.tick(clock.now).phase, RitualPhase.intro);
    expect(m.tick(clock.now).ambientGain, 1.0);

    expect(step(m, const Duration(seconds: 59)).phase, RitualPhase.intro);
    final v = step(m, const Duration(seconds: 1));
    expect(v.phase, RitualPhase.voice);
    expect(v.voiceActive, isTrue);

    // Ducking ramps to 0.6 and stays there for the whole tale.
    expect(step(m, const Duration(seconds: 3)).ambientGain, closeTo(0.6, 1e-9));
    expect(step(m, const Duration(minutes: 30)).phase, RitualPhase.voice);

    m.voiceCompleted(clock.now);
    expect(m.tick(clock.now).phase, RitualPhase.tail);
    expect(step(m, const Duration(seconds: 3)).ambientGain, closeTo(1.0, 1e-9));
    expect(step(m, const Duration(minutes: 19, seconds: 56)).phase, RitualPhase.tail);

    final f = step(m, const Duration(seconds: 31));
    expect(f.phase, RitualPhase.fadeOut);
    expect(f.ambientGain, closeTo(0.5, 0.01));
    expect(step(m, const Duration(seconds: 30)).phase, RitualPhase.done);
    expect(m.tick(clock.now).ambientGain, 0);
  });

  test('intro countdown and skip', () {
    final m = RitualMachine(const RitualConfig())..start(clock.now);
    step(m, const Duration(seconds: 18));
    expect(m.introRemaining, const Duration(seconds: 42));
    clock.advance(const Duration(seconds: 2));
    m.skipIntro(clock.now);
    expect(m.introRemaining, isNull);
    final f = m.tick(clock.now);
    expect(f.phase, RitualPhase.voice);
    expect(f.voiceActive, isTrue);
    // Skipping outside the intro does nothing.
    m.skipIntro(clock.now);
    expect(m.phase, RitualPhase.voice);
  });

  test('intro label counts down to the voice', () {
    PlayerState intro(Duration? left) =>
        PlayerState(kind: SessionKind.tale, phase: RitualPhase.intro, introRemaining: left);
    expect(phaseLabel(intro(const Duration(seconds: 41, milliseconds: 200))), 'Pohádka začne za 0:42');
    expect(phaseLabel(intro(const Duration(seconds: 90))), 'Pohádka začne za 1:30');
    expect(phaseLabel(intro(null)), 'Jen podkres…');
  });

  test('pause freezes phase time', () {
    final m = RitualMachine(const RitualConfig())..start(clock.now);
    step(m, const Duration(seconds: 30));
    m.pause(clock.now);
    expect(step(m, const Duration(minutes: 10)).phase, RitualPhase.intro);
    m.resume(clock.now);
    expect(step(m, const Duration(seconds: 29)).phase, RitualPhase.intro);
    expect(step(m, const Duration(seconds: 1)).phase, RitualPhase.voice);
  });

  test('late tick crosses tail and fade in one go', () {
    final m = RitualMachine(const RitualConfig(tail: Duration(minutes: 1)))..start(clock.now);
    step(m, const Duration(minutes: 1));
    m.voiceCompleted(clock.now);
    expect(step(m, const Duration(minutes: 5)).phase, RitualPhase.done);
  });

  test('ritual off: voice at once, ducked fade right after it', () {
    final m = RitualMachine(const RitualConfig.off())..start(clock.now);
    expect(m.tick(clock.now).phase, RitualPhase.voice);
    step(m, const Duration(minutes: 10));
    m.voiceCompleted(clock.now);
    final f = m.tick(clock.now);
    expect(f.phase, RitualPhase.fadeOut);
    expect(f.ambientGain, closeTo(0.6, 1e-9));
    expect(step(m, const Duration(seconds: 60)).phase, RitualPhase.done);
  });

  test('voiceCompleted outside voice phase is ignored', () {
    final m = RitualMachine(const RitualConfig())..start(clock.now);
    m.voiceCompleted(clock.now);
    expect(m.tick(clock.now).phase, RitualPhase.intro);
  });
}
