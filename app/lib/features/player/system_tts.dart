import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/script/script.dart';
import '../../core/script/tone.dart';
import 'voice_source.dart';

const systemVoiceId = 'system';

/// flutter_tts locale for each app language (docs/I18N_PLAN.md).
const ttsLocales = {
  'cs': 'cs-CZ', 'en': 'en-US', 'de': 'de-DE', 'es': 'es-ES', 'fr': 'fr-FR',
  'pt-BR': 'pt-BR', 'it': 'it-IT', 'pl': 'pl-PL', 'sk': 'sk-SK',
};

/// Whether voice [v] speaks [lang]. `pt-BR` needs the Brazilian voice;
/// other languages take any region.
bool _speaks(Map<String, String> v, String lang) {
  final l = (v['locale'] ?? '').toLowerCase().replaceAll('_', '-');
  final want = lang.toLowerCase();
  if (want.contains('-')) return l == want;
  return l == want || l.startsWith('$want-');
}

int _qualityRank(String? q) => switch (q) {
      'premium' || 'very high' => 5,
      'enhanced' || 'high' => 4,
      'normal' || 'default' => 3,
      'low' => 2,
      'very low' => 1,
      _ => 0,
    };

/// Best installed voice for [lang] from flutter_tts `getVoices`: iOS
/// premium > enhanced > default, Android by quality, voices needing network
/// last, the language's main region ([ttsLocales]) breaking ties.
/// Null = no voice for [lang] on this phone.
Map<String, String>? pickVoice(Iterable<Map<String, String>> voices, String lang) {
  final main = (ttsLocales[lang] ?? lang).toLowerCase();
  Map<String, String>? best;
  var bestScore = -1;
  for (final v in voices.where((v) => _speaks(v, lang))) {
    final offline = v['network_required'] == '1' ? 0 : 20;
    final region = (v['locale'] ?? '').toLowerCase().replaceAll('_', '-') == main ? 1 : 0;
    final score = offline + 2 * _qualityRank(v['quality']) + region;
    if (score > bestScore) {
      best = v;
      bestScore = score;
    }
  }
  return best;
}

Map<String, String>? pickCzechVoice(Iterable<Map<String, String>> voices) => pickVoice(voices, 'cs');

List<Map<String, String>> _voiceMaps(Object? raw) => [
      if (raw is List)
        for (final v in raw)
          if (v is Map) {for (final e in v.entries) '${e.key}': '${e.value}'},
    ];

/// The phone's own TTS (`flutter_tts`), one utterance at a time.
class SystemTtsSource implements VoiceSource {
  SystemTtsSource({FlutterTts? tts, bool? ios, this._lang = 'cs'})
      : _tts = tts ?? FlutterTts(),
        _ios = ios ?? defaultTargetPlatform == TargetPlatform.iOS;

  final FlutterTts _tts;
  final bool _ios;
  String _lang;
  Future<Map<String, String>?>? _setup;
  Future<void>? _handlers;
  Completer<void>? _current;

  /// A cancel event for an utterance we stopped ourselves is still on its
  /// way; it must not end the next utterance.
  bool _expectCancel = false;
  double _gain = 1;

  /// The voice in use for the current language, or null when the phone has none.
  Future<Map<String, String>?> voice() => _setup ??= _init();

  /// Switch to [lang]; the next utterance picks its voice.
  void setLang(String lang) {
    if (lang == _lang) return;
    _lang = lang;
    _setup = null;
  }

  Future<Map<String, String>?> _init() async {
    await (_handlers ??= _initHandlers());
    final locale = ttsLocales[_lang] ?? _lang;
    await _tts.setLanguage(locale);
    try {
      final voice = pickVoice(_voiceMaps(await _tts.getVoices), _lang);
      if (voice != null) {
        await _tts.setVoice({
          'name': voice['name'] ?? '',
          'locale': voice['locale'] ?? locale,
          if (voice['identifier'] != null) 'identifier': voice['identifier']!,
        });
      }
      return voice;
    } on Object catch (e) {
      debugPrint('TTS voices: $e');
      return null;
    }
  }

  Future<void> _initHandlers() async {
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
  }

  @override
  Future<void> speak(Utterance u, ToneParams tone) async {
    await voice();
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
