import 'dart:async';
import 'dart:io';

import '../../core/script/script.dart';
import '../../core/script/tone.dart';

/// Speaks one utterance at a time. [speak] completes when the utterance has
/// finished or after [stop]; stopping mid-utterance is how pause works (the
/// sequencer replays the utterance on resume).
abstract interface class VoiceSource {
  Future<void> speak(Utterance u, ToneParams tone);
  Future<void> stop();

  /// Master gain (balance × sleep-timer fade). Clips apply it at once, the
  /// system voice from the next utterance.
  void setGain(double gain);
}

/// Plays one audio file; seam over just_audio so the cloned voice is
/// testable. [play] completes when the file ends or after [stop].
abstract interface class ClipOutput {
  Future<void> play(String path, double volume);
  void setVolume(double volume);
  Future<void> stop();
}

/// The parent's cloned voice: a pre-rendered clip per utterance
/// (`{dir}/{utterance_key}.m4a`, CONTRACTS §7–8). A missing clip is read by
/// [fallback] (the phone's voice), so a voice still being prepared works.
class ClonedVoiceSource implements VoiceSource {
  ClonedVoiceSource({
    required this.voiceId,
    required this.clipDir,
    required this.output,
    required this.fallback,
    bool Function(String path)? exists,
  }) : _exists = exists ?? ((p) => File(p).existsSync());

  final String voiceId;
  final String clipDir;
  final ClipOutput output;
  final VoiceSource fallback;
  final bool Function(String path) _exists;
  double _gain = 1;
  double _toneVolume = 1;

  String clipPath(Utterance u) => '$clipDir/${u.keyFor(voiceId)}.m4a';

  @override
  Future<void> speak(Utterance u, ToneParams tone) {
    final path = clipPath(u);
    if (!_exists(path)) return fallback.speak(u, tone);
    _toneVolume = tone.volume;
    return output.play(path, _toneVolume * _gain);
  }

  @override
  Future<void> stop() async {
    await Future.wait([output.stop(), fallback.stop()]);
  }

  @override
  void setGain(double gain) {
    if (gain == _gain) return;
    _gain = gain;
    output.setVolume(_toneVolume * gain);
    fallback.setGain(gain);
  }
}

/// No voice at all (widget tests, or no TTS on the device): utterances pass
/// instantly so the ritual still moves on.
class SilentVoiceSource implements VoiceSource {
  @override
  Future<void> speak(Utterance u, ToneParams tone) async {}
  @override
  Future<void> stop() async {}
  @override
  void setGain(double gain) {}
}
