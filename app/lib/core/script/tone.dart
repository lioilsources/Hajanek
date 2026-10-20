// Tone → delivery mapping (docs/CONTRACTS.md §2). Rates are relative to the
// voice's normal speed; volumes multiply the voice track volume.

import 'dart:math' as math;

import 'script.dart';

enum Tone { soft, slow, whisper }

class ToneParams {
  const ToneParams({required this.rate, required this.volume, this.pitch = 1.0});
  final double rate;
  final double volume;

  /// Only the system voice uses pitch (it can't whisper).
  final double pitch;

  @override
  bool operator ==(Object other) =>
      other is ToneParams && other.rate == rate && other.volume == volume && other.pitch == pitch;
  @override
  int get hashCode => Object.hash(rate, volume, pitch);
  @override
  String toString() => 'ToneParams(rate: $rate, volume: $volume, pitch: $pitch)';
}

const toneTable = <Tone, ToneParams>{
  Tone.soft: ToneParams(rate: 0.85, volume: 1.0),
  Tone.slow: ToneParams(rate: 0.78, volume: 0.75),
  Tone.whisper: ToneParams(rate: 0.75, volume: 0.4, pitch: 0.95),
};

/// Where the dojezd ramp ends (last utterance of the section).
const dojezdRampRate = 0.75;
const dojezdRampVolume = 0.5;

/// Delivery for [u]: the tone table, and in `dojezd` a linear ramp by
/// position towards [dojezdRampRate] / [dojezdRampVolume]. The ramp only
/// ever slows down and quietens — a whisper never gets louder.
ToneParams toneFor(Utterance u) {
  final base = toneTable[u.tone]!;
  if (u.section != 'dojezd') return base;
  final t = u.sectionSize <= 1 ? 1.0 : u.indexInSection / (u.sectionSize - 1);
  double lerp(double a, double b) => a + (b - a) * t;
  return ToneParams(
    rate: math.min(base.rate, lerp(base.rate, dojezdRampRate)),
    volume: math.min(base.volume, lerp(base.volume, dojezdRampVolume)),
    pitch: base.pitch,
  );
}

/// flutter_tts speech rate: iOS AVSpeechUtterance 0.5 = normal, Android 1.0.
double platformSpeechRate(double relative, {required bool ios}) => relative * (ios ? 0.5 : 1.0);
