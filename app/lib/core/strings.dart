import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart' show AppLocalizations;

/// Languages of the app UI (lib/l10n/app_*.arb). [fallbackLang] is used
/// when the phone speaks none of them.
const supportedLangs = [
  'cs', 'en', 'de', 'es', 'fr', 'pt-BR', 'it', 'pl', 'sk', //
  'ar', 'bn', 'ca', 'da', 'el', 'fi', 'gu', 'he', 'hi', 'hr', 'hu', 'id', 'ja', 'kn', 'ko',
  'ml', 'mr', 'ms', 'nb', 'nl', 'or', 'pa', 'pt-PT', 'ro', 'ru', 'sl', 'sv', 'ta', 'te', 'th',
  'tr', 'uk', 'ur', 'vi', 'zh-Hans', 'zh-Hant',
];
const fallbackLang = 'en';

/// Languages the tales exist in (content/i18n, docs/I18N_PLAN.md). The first
/// is the source language. Other UI languages read the tales in
/// [taleLangFor].
const taleLangs = ['cs', 'en', 'de', 'es', 'fr', 'pt-BR', 'it', 'pl', 'sk'];

/// Each language in itself, for the language picker.
const langNames = {
  'cs': 'Čeština', 'en': 'English', 'de': 'Deutsch', 'es': 'Español', 'fr': 'Français',
  'pt-BR': 'Português (Brasil)', 'it': 'Italiano', 'pl': 'Polski', 'sk': 'Slovenčina',
  'ar': 'العربية', 'bn': 'বাংলা', 'ca': 'Català', 'da': 'Dansk', 'el': 'Ελληνικά',
  'fi': 'Suomi', 'gu': 'ગુજરાતી', 'he': 'עברית', 'hi': 'हिन्दी', 'hr': 'Hrvatski',
  'hu': 'Magyar', 'id': 'Bahasa Indonesia', 'ja': '日本語', 'kn': 'ಕನ್ನಡ', 'ko': '한국어',
  'ml': 'മലയാളം', 'mr': 'मराठी', 'ms': 'Bahasa Melayu', 'nb': 'Norsk bokmål',
  'nl': 'Nederlands', 'or': 'ଓଡ଼ିଆ', 'pa': 'ਪੰਜਾਬੀ', 'pt-PT': 'Português (Portugal)',
  'ro': 'Română', 'ru': 'Русский', 'sl': 'Slovenščina', 'sv': 'Svenska', 'ta': 'தமிழ்',
  'te': 'తెలుగు', 'th': 'ไทย', 'tr': 'Türkçe', 'uk': 'Українська', 'ur': 'اردو',
  'vi': 'Tiếng Việt', 'zh-Hans': '简体中文', 'zh-Hant': '繁體中文',
};

/// `pt-BR` → `Locale('pt', 'BR')`, `zh-Hans` → script `Hans`.
Locale langLocale(String lang) {
  final p = lang.split('-');
  if (p.length > 1 && p[1].length == 4) return Locale.fromSubtags(languageCode: p[0], scriptCode: p[1]);
  return Locale(p[0], p.length > 1 ? p[1] : null);
}

/// The tag of [l] as [supportedLangs] spells it, where it differs from the
/// plain language code: Chinese by script, Portuguese by country, Norwegian.
String _tagOf(Locale l) {
  switch (l.languageCode) {
    case 'zh':
      final script = l.scriptCode ?? (const {'TW', 'HK', 'MO'}.contains(l.countryCode) ? 'Hant' : 'Hans');
      return 'zh-$script';
    case 'pt':
      return l.countryCode == null || l.countryCode == 'BR' ? 'pt-BR' : 'pt-PT';
    case 'no' || 'nn':
      return 'nb';
  }
  return l.countryCode == null ? l.languageCode : '${l.languageCode}-${l.countryCode}';
}

/// Best supported language for the phone's locales, else [fallbackLang].
String langFor(Iterable<Locale> locales) {
  for (final l in locales) {
    final tag = _tagOf(l);
    if (supportedLangs.contains(tag)) return tag;
    for (final s in supportedLangs) {
      if (s.split('-').first == l.languageCode) return s;
    }
  }
  return fallbackLang;
}

/// The language of the tales and the voice for UI language [lang]: the same
/// one if the tales exist in it, else one of the same base language, else
/// [fallbackLang].
String taleLangFor(String lang) {
  if (taleLangs.contains(lang)) return lang;
  final base = lang.split('-').first;
  for (final t in taleLangs) {
    if (t.split('-').first == base) return t;
  }
  return fallbackLang;
}

AppLocalizations _strings = lookupAppLocalizations(const Locale('cs'));
String _lang = 'cs';

/// All user-facing strings (lib/l10n/app_*.arb) in the current language.
/// A global rather than `AppLocalizations.of(context)` because controllers
/// and the media notification need them too; [setStringsLang] switches it
/// and the app root rebuilds.
// ignore: non_constant_identifier_names
AppLocalizations get S => _strings;

/// The language [S] speaks.
String get stringsLang => _lang;

void setStringsLang(String lang) {
  final locale = langLocale(lang);
  _lang = lang;
  _strings = lookupAppLocalizations(
      AppLocalizations.delegate.isSupported(locale) ? locale : const Locale('cs'));
}

const appName = 'Hajánek';

/// Strings computed from the ARB ones.
extension StringsX on AppLocalizations {
  String homeMinutes(double seconds) => minutes((seconds / 60).round());
  String timerMinutes(int m) => minutes(m);
  String settingsMinutes(int m) => minutes(m);
  String settingsSeconds(int s) => seconds(s);

  String section(String? id) => switch (id) {
        'uvod' => sectionUvod,
        'vstup' => sectionVstup,
        'pribeh' => sectionPribeh,
        'dojezd' => sectionDojezd,
        _ => '',
      };

  String tvRitual(bool on) => '$detailRitual: ${on ? tvOn : tvOff}';

  String tvBalanceLabel(double b) => switch ((b * 4).round()) {
        0 => balanceVoiceOnly,
        1 => balanceMoreVoice,
        2 => balanceEven,
        3 => balanceMoreBackground,
        _ => balanceBackgroundOnly,
      };

  String timerRemaining(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String pairCodeSpaced(String code) =>
      code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;
}
