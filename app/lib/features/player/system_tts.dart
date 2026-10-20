import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/script/script.dart';
import '../../core/script/tone.dart';
import 'voice_source.dart';

const systemVoiceId = 'system';

bool _isCzech(Map<String, String> v) {
  final l = (v['locale'] ?? '').toLowerCase().replaceAll('_', '-');
  return l == 'cs' || l.startsWith('cs-');
}

int _qualityRank(String? q) => switch (q) {
      'premium' || 'very high' => 5,
      'enhanced' || 'high' => 4,
      'normal' || 'default' => 3,
      'low' => 2,
      'very low' => 1,
      _ => 0,
    };

/// Best installed Czech voice from flutter_tts `getVoices`: iOS premium >
/// enhanced > default, Android by quality, voices needing network last.
/// Null = no Czech voice on this phone.
Map<String, String>? pickCzechVoice(Iterable<Map<String, String>> voices) {
  Map<String, String>? best;
  var bestScore = -1;
  for (final v in voices.where(_isCzech)) {
    final offline = v['network_required'] == '1' ? 0 : 10;
    final score = offline + _qualityRank(v['quality']);
    if (score > bestScore) {
      best = v;
      bestScore = score;
    }
  }
  return best;
}

List<Map<String, String>> _voiceMaps(Object? raw) => [
      if (raw is List)
        for (final v in raw)
          if (v is Map) {for (final e in v.entries) '${e.key}': '${e.value}'},
    ];

/// The phone's own TTS (`flutter_tts`), one utterance at a time.
class SystemTtsSource implements VoiceSource {
  SystemTtsSource({FlutterTts? tts, bool? ios})
      : _tts = tts ?? FlutterTts(),
        _ios = ios ?? defaultTargetPlatform == TargetPlatform.iOS;

  final FlutterTts _tts;
  final bool _ios;
  Future<Map<String, String>?>? _setup;
  Completer<void>? _current;

  /// A cancel event for an utterance we stopped ourselves is still on its
  /// way; it must not end the next utterance.
  bool _expectCancel = false;
  double _gain = 1;

  /// The Czech voice in use, or null when the phone has none.
  Future<Map<String, String>?> czechVoice() => _setup ??= _init();

  Future<Map<String, String>?> _init() async {
    _tts
      ..setCompletionHandler(_finish)
      ..setCancelHandler(() {
        if (_expectCancel) {
          _expectCancel = false;
          return;
        }
        _finish();
      })
      ..setErrorHandler((_) => _finish());
    if (_ios) {
      // Keep the shared AVAudioSession (category playback, set up by
      // audio_session in main) active after each utterance, so speech and
      // ambient go on with the screen locked.
      await _tts.setSharedInstance(true);
      await _tts.autoStopSharedSession(false);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        const [],
        IosTextToSpeechAudioMode.spokenAudio,
      );
    }
    await _tts.setLanguage('cs-CZ');
    try {
      final voice = pickCzechVoice(_voiceMaps(await _tts.getVoices));
      if (voice != null) {
        await _tts.setVoice({
          'name': voice['name'] ?? '',
          'locale': voice['locale'] ?? 'cs-CZ',
          if (voice['identifier'] != null) 'identifier': voice['identifier']!,
        });
      }
      return voice;
    } on Object catch (e) {
      debugPrint('TTS voices: $e');
      return null;
    }
  }

  @override
  Future<void> speak(Utterance u, ToneParams tone) async {
    await czechVoice();
    _finish();
    final c = _current = Completer<void>();
    await _tts.setSpeechRate(platformSpeechRate(tone.rate, ios: _ios));
    await _tts.setVolume((tone.volume * _gain).clamp(0.0, 1.0));
    await _tts.setPitch(tone.pitch);
    if (!identical(_current, c)) return; // stopped while configuring
    final r = await _tts.speak(u.text);
    if (r != 1) _finish();
    return c.future;
  }

  @override
  Future<void> stop() async {
    if (_current != null) _expectCancel = true;
    _finish();
    await _tts.stop();
  }

  @override
  void setGain(double gain) => _gain = gain;

  void _finish() {
    final c = _current;
    _current = null;
    if (c != null && !c.isCompleted) c.complete();
  }
}
