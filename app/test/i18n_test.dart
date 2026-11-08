import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hajanek/core/strings.dart';
import 'package:hajanek/features/player/system_tts.dart';

void main() {
  test('the phone language picks the app language, English otherwise', () {
    expect(langFor(const [Locale('cs', 'CZ')]), 'cs');
    expect(langFor(const [Locale('pt', 'BR')]), 'pt-BR');
    expect(langFor(const [Locale('pt', 'PT')]), 'pt-BR');
    expect(langFor(const [Locale('de', 'AT')]), 'de');
    expect(langFor(const [Locale('ja'), Locale('sk', 'SK')]), 'sk');
    expect(langFor(const [Locale('ja')]), 'en');
  });

  test('every supported language has strings and a TTS locale', () {
    for (final l in supportedLangs) {
      expect(AppLocalizations.delegate.isSupported(langLocale(l)), isTrue, reason: l);
      expect(ttsLocales[l], isNotNull, reason: l);
      expect(langNames[l], isNotNull, reason: l);
    }
  });

  test('voice per language: offline and quality first, pt-BR only Brazilian', () {
    const voices = [
      {'name': 'Zuzana', 'locale': 'cs-CZ', 'quality': 'default'},
      {'name': 'Daniel', 'locale': 'en-GB', 'quality': 'enhanced'},
      {'name': 'Samantha', 'locale': 'en-US', 'quality': 'default'},
      {'name': 'Ava', 'locale': 'en-US', 'quality': 'enhanced'},
      {'name': 'net', 'locale': 'en-US', 'quality': 'very high', 'network_required': '1'},
      {'name': 'Joana', 'locale': 'pt-PT', 'quality': 'premium'},
      {'name': 'Luciana', 'locale': 'pt_BR', 'quality': 'default'},
    ];
    expect(pickVoice(voices, 'en')?['name'], 'Ava');
    expect(pickVoice(voices, 'pt-BR')?['name'], 'Luciana');
    expect(pickVoice(voices, 'cs')?['name'], 'Zuzana');
    expect(pickVoice(voices, 'de'), isNull);
  });
}
