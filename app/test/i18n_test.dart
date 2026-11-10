import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hajanek/core/strings.dart';
import 'package:hajanek/l10n/app_localizations.dart' show lookupAppLocalizations;
import 'package:hajanek/features/player/system_tts.dart';

void main() {
  test('the phone language picks the app language, English otherwise', () {
    expect(langFor(const [Locale('cs', 'CZ')]), 'cs');
    expect(langFor(const [Locale('pt', 'BR')]), 'pt-BR');
    expect(langFor(const [Locale('pt', 'PT')]), 'pt-PT');
    expect(langFor(const [Locale('pt')]), 'pt-BR');
    expect(langFor(const [Locale('de', 'AT')]), 'de');
    expect(langFor(const [Locale('xx'), Locale('sk', 'SK')]), 'sk');
    expect(langFor(const [Locale('ja')]), 'ja');
    expect(langFor(const [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW')]), 'zh-Hant');
    expect(langFor(const [Locale('zh', 'HK')]), 'zh-Hant');
    expect(langFor(const [Locale('zh', 'CN')]), 'zh-Hans');
    expect(langFor(const [Locale('no')]), 'nb');
    expect(langFor(const [Locale('xx')]), 'en');
  });

  test('tales play in the UI language, the same base language, else English', () {
    expect(taleLangFor('sk'), 'sk');
    expect(taleLangFor('pt-PT'), 'pt-BR');
    expect(taleLangFor('ja'), 'en');
    expect(taleLangFor('ar'), 'en');
    for (final l in supportedLangs) {
      expect(taleLangs, contains(taleLangFor(l)), reason: l);
    }
  });

  test('every UI language has strings and a name, every tale language a TTS locale', () {
    for (final l in supportedLangs) {
      expect(AppLocalizations.delegate.isSupported(langLocale(l)), isTrue, reason: l);
      expect(langNames[l], isNotNull, reason: l);
    }
    for (final l in taleLangs) {
      expect(ttsLocales[l], isNotNull, reason: l);
    }
  });

  test('scripts and regions pick their own strings', () {
    expect(lookupAppLocalizations(langLocale('zh-Hant')).homeTales, '童話');
    expect(lookupAppLocalizations(langLocale('zh-Hans')).homeTales, '童话');
    expect(lookupAppLocalizations(langLocale('pt-PT')).settingsTitle, 'Definições');
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
