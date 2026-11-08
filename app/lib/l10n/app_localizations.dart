import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_cs.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('cs')];

  /// No description provided for @homeJukebox.
  ///
  /// In cs, this message translates to:
  /// **'Jukebox zvuků'**
  String get homeJukebox;

  /// No description provided for @homeJukeboxSub.
  ///
  /// In cs, this message translates to:
  /// **'Jen podkres, bez pohádky'**
  String get homeJukeboxSub;

  /// No description provided for @homeTales.
  ///
  /// In cs, this message translates to:
  /// **'Pohádky'**
  String get homeTales;

  /// No description provided for @homeNowPlaying.
  ///
  /// In cs, this message translates to:
  /// **'Právě hraje'**
  String get homeNowPlaying;

  /// No description provided for @detailVoice.
  ///
  /// In cs, this message translates to:
  /// **'Hlas'**
  String get detailVoice;

  /// No description provided for @detailNoScript.
  ///
  /// In cs, this message translates to:
  /// **'Text pohádky se nepodařilo načíst.'**
  String get detailNoScript;

  /// No description provided for @detailBackground.
  ///
  /// In cs, this message translates to:
  /// **'Podkres'**
  String get detailBackground;

  /// No description provided for @detailRecommended.
  ///
  /// In cs, this message translates to:
  /// **'Doporučený'**
  String get detailRecommended;

  /// No description provided for @detailNoBackground.
  ///
  /// In cs, this message translates to:
  /// **'Bez podkresu'**
  String get detailNoBackground;

  /// No description provided for @detailRitual.
  ///
  /// In cs, this message translates to:
  /// **'Rituál „dobrou noc“'**
  String get detailRitual;

  /// No description provided for @detailRitualSub.
  ///
  /// In cs, this message translates to:
  /// **'Nejdřív jen podkres, po pohádce ještě chvíli hraje'**
  String get detailRitualSub;

  /// No description provided for @detailPlay.
  ///
  /// In cs, this message translates to:
  /// **'Spustit'**
  String get detailPlay;

  /// No description provided for @detailFavourite.
  ///
  /// In cs, this message translates to:
  /// **'Oblíbená'**
  String get detailFavourite;

  /// No description provided for @playerIntro.
  ///
  /// In cs, this message translates to:
  /// **'Jen podkres…'**
  String get playerIntro;

  /// No description provided for @playerStartNow.
  ///
  /// In cs, this message translates to:
  /// **'Začít hned'**
  String get playerStartNow;

  /// No description provided for @playerVoice.
  ///
  /// In cs, this message translates to:
  /// **'Pohádka'**
  String get playerVoice;

  /// No description provided for @playerTail.
  ///
  /// In cs, this message translates to:
  /// **'Podkres doznívá'**
  String get playerTail;

  /// No description provided for @playerFadeOut.
  ///
  /// In cs, this message translates to:
  /// **'Utichá…'**
  String get playerFadeOut;

  /// No description provided for @playerDone.
  ///
  /// In cs, this message translates to:
  /// **'Dobrou noc'**
  String get playerDone;

  /// No description provided for @playerMixer.
  ///
  /// In cs, this message translates to:
  /// **'Jukebox'**
  String get playerMixer;

  /// No description provided for @playerBalance.
  ///
  /// In cs, this message translates to:
  /// **'Hlas ↔ podkres'**
  String get playerBalance;

  /// No description provided for @playerBackground.
  ///
  /// In cs, this message translates to:
  /// **'Podkres'**
  String get playerBackground;

  /// No description provided for @playerStop.
  ///
  /// In cs, this message translates to:
  /// **'Zastavit'**
  String get playerStop;

  /// No description provided for @playerNothing.
  ///
  /// In cs, this message translates to:
  /// **'Nic nehraje'**
  String get playerNothing;

  /// No description provided for @mixerTitle.
  ///
  /// In cs, this message translates to:
  /// **'Jukebox zvuků'**
  String get mixerTitle;

  /// No description provided for @mixerMain.
  ///
  /// In cs, this message translates to:
  /// **'Hlavní zvuk'**
  String get mixerMain;

  /// No description provided for @mixerSecondary.
  ///
  /// In cs, this message translates to:
  /// **'Vedlejší zvuk'**
  String get mixerSecondary;

  /// No description provided for @mixerAddLayer.
  ///
  /// In cs, this message translates to:
  /// **'Přidat vrstvu'**
  String get mixerAddLayer;

  /// No description provided for @mixerPresets.
  ///
  /// In cs, this message translates to:
  /// **'Předvolby'**
  String get mixerPresets;

  /// No description provided for @mixerSavePreset.
  ///
  /// In cs, this message translates to:
  /// **'Uložit předvolbu'**
  String get mixerSavePreset;

  /// No description provided for @mixerPresetName.
  ///
  /// In cs, this message translates to:
  /// **'Název předvolby'**
  String get mixerPresetName;

  /// No description provided for @mixerSave.
  ///
  /// In cs, this message translates to:
  /// **'Uložit'**
  String get mixerSave;

  /// No description provided for @mixerCancel.
  ///
  /// In cs, this message translates to:
  /// **'Zrušit'**
  String get mixerCancel;

  /// No description provided for @mixerDeletePreset.
  ///
  /// In cs, this message translates to:
  /// **'Smazat předvolbu?'**
  String get mixerDeletePreset;

  /// No description provided for @mixerDelete.
  ///
  /// In cs, this message translates to:
  /// **'Smazat'**
  String get mixerDelete;

  /// No description provided for @mixerRemoveLayer.
  ///
  /// In cs, this message translates to:
  /// **'Odebrat vrstvu'**
  String get mixerRemoveLayer;

  /// No description provided for @mixerGroupNature.
  ///
  /// In cs, this message translates to:
  /// **'Přírodní zvuky'**
  String get mixerGroupNature;

  /// No description provided for @mixerGroupMusic.
  ///
  /// In cs, this message translates to:
  /// **'Ukolébavky'**
  String get mixerGroupMusic;

  /// No description provided for @timerTitle.
  ///
  /// In cs, this message translates to:
  /// **'Časovač'**
  String get timerTitle;

  /// No description provided for @timerOff.
  ///
  /// In cs, this message translates to:
  /// **'Vypnuto'**
  String get timerOff;

  /// No description provided for @timerEndOfTale.
  ///
  /// In cs, this message translates to:
  /// **'Po dohrání'**
  String get timerEndOfTale;

  /// No description provided for @settingsTitle.
  ///
  /// In cs, this message translates to:
  /// **'Nastavení'**
  String get settingsTitle;

  /// No description provided for @settingsBreathing.
  ///
  /// In cs, this message translates to:
  /// **'Dýchající kruh'**
  String get settingsBreathing;

  /// No description provided for @settingsBreathingSub.
  ///
  /// In cs, this message translates to:
  /// **'Jediný pohyb na obrazovce přehrávače'**
  String get settingsBreathingSub;

  /// No description provided for @settingsIntro.
  ///
  /// In cs, this message translates to:
  /// **'Úvodní podkres (rituál)'**
  String get settingsIntro;

  /// No description provided for @settingsTail.
  ///
  /// In cs, this message translates to:
  /// **'Doznívání podkresu (rituál)'**
  String get settingsTail;

  /// No description provided for @settingsTimer.
  ///
  /// In cs, this message translates to:
  /// **'Výchozí časovač'**
  String get settingsTimer;

  /// No description provided for @settingsCatalog.
  ///
  /// In cs, this message translates to:
  /// **'Katalog'**
  String get settingsCatalog;

  /// No description provided for @settingsCheckUpdates.
  ///
  /// In cs, this message translates to:
  /// **'Zkontrolovat aktualizace'**
  String get settingsCheckUpdates;

  /// No description provided for @settingsChecking.
  ///
  /// In cs, this message translates to:
  /// **'Kontroluji…'**
  String get settingsChecking;

  /// No description provided for @settingsUpToDate.
  ///
  /// In cs, this message translates to:
  /// **'Katalog je aktuální'**
  String get settingsUpToDate;

  /// No description provided for @settingsUpdated.
  ///
  /// In cs, this message translates to:
  /// **'Katalog aktualizován'**
  String get settingsUpdated;

  /// No description provided for @settingsOffline.
  ///
  /// In cs, this message translates to:
  /// **'Bez připojení — vše funguje offline'**
  String get settingsOffline;

  /// No description provided for @settingsVoice.
  ///
  /// In cs, this message translates to:
  /// **'Hlas'**
  String get settingsVoice;

  /// No description provided for @settingsVocative.
  ///
  /// In cs, this message translates to:
  /// **'Oslovení dítěte'**
  String get settingsVocative;

  /// No description provided for @settingsVocativeSub.
  ///
  /// In cs, this message translates to:
  /// **'V 5. pádě, např. „Aničko“. Zatím se nepoužívá.'**
  String get settingsVocativeSub;

  /// No description provided for @settingsVocativeNone.
  ///
  /// In cs, this message translates to:
  /// **'Nenastaveno'**
  String get settingsVocativeNone;

  /// No description provided for @settingsPrivacy.
  ///
  /// In cs, this message translates to:
  /// **'Žádný účet, žádná analytika. Síť se používá jen pro aktualizaci katalogu.'**
  String get settingsPrivacy;

  /// No description provided for @settingsPrivacyCloning.
  ///
  /// In cs, this message translates to:
  /// **'Žádný účet, žádná analytika. Síť se používá jen pro aktualizaci katalogu a pro tvůj nahraný hlas.'**
  String get settingsPrivacyCloning;

  /// No description provided for @voiceTitle.
  ///
  /// In cs, this message translates to:
  /// **'Hlas'**
  String get voiceTitle;

  /// No description provided for @voiceSystem.
  ///
  /// In cs, this message translates to:
  /// **'Hlas telefonu'**
  String get voiceSystem;

  /// No description provided for @voiceSystemSub.
  ///
  /// In cs, this message translates to:
  /// **'Funguje hned a bez internetu'**
  String get voiceSystemSub;

  /// No description provided for @voiceRecord.
  ///
  /// In cs, this message translates to:
  /// **'Nahrát můj hlas'**
  String get voiceRecord;

  /// No description provided for @voiceBeta.
  ///
  /// In cs, this message translates to:
  /// **'Zkušební verze zdarma. Hlas se připravuje několik hodin.'**
  String get voiceBeta;

  /// No description provided for @voicePending.
  ///
  /// In cs, this message translates to:
  /// **'Hlas se připravuje, bude hotový do rána'**
  String get voicePending;

  /// No description provided for @voiceReady.
  ///
  /// In cs, this message translates to:
  /// **'Připraveno'**
  String get voiceReady;

  /// No description provided for @voiceWaiting.
  ///
  /// In cs, this message translates to:
  /// **'Hlas je hotový, čekám na první věty'**
  String get voiceWaiting;

  /// No description provided for @voiceFailed.
  ///
  /// In cs, this message translates to:
  /// **'Hlas se nepodařilo vytvořit. Zkus nahrávku zopakovat.'**
  String get voiceFailed;

  /// No description provided for @voiceDelete.
  ///
  /// In cs, this message translates to:
  /// **'Smazat hlas'**
  String get voiceDelete;

  /// No description provided for @voiceCancel.
  ///
  /// In cs, this message translates to:
  /// **'Zrušit'**
  String get voiceCancel;

  /// No description provided for @voiceMissingClips.
  ///
  /// In cs, this message translates to:
  /// **'Věty, které ještě nejsou stažené, přečte zatím hlas telefonu.'**
  String get voiceMissingClips;

  /// No description provided for @voiceHintTitle.
  ///
  /// In cs, this message translates to:
  /// **'Telefon nemá český hlas'**
  String get voiceHintTitle;

  /// No description provided for @voiceHintIos.
  ///
  /// In cs, this message translates to:
  /// **'Nainstaluj ho v Nastavení → Zpřístupnění → Předčítání → Hlasy → Čeština (nejlépe Zuzana ve vylepšené kvalitě).'**
  String get voiceHintIos;

  /// No description provided for @voiceHintAndroid.
  ///
  /// In cs, this message translates to:
  /// **'Nainstaluj ho v Nastavení → Převod textu na řeč → Google → Nainstalovat hlasová data → čeština.'**
  String get voiceHintAndroid;

  /// No description provided for @voiceHintOk.
  ///
  /// In cs, this message translates to:
  /// **'Rozumím'**
  String get voiceHintOk;

  /// No description provided for @recTitle.
  ///
  /// In cs, this message translates to:
  /// **'Nahrát můj hlas'**
  String get recTitle;

  /// No description provided for @recName.
  ///
  /// In cs, this message translates to:
  /// **'Tvoje jméno'**
  String get recName;

  /// No description provided for @recNameHint.
  ///
  /// In cs, this message translates to:
  /// **'např. Jana'**
  String get recNameHint;

  /// No description provided for @recTips.
  ///
  /// In cs, this message translates to:
  /// **'Než začneš'**
  String get recTips;

  /// No description provided for @recRead.
  ///
  /// In cs, this message translates to:
  /// **'Přečti nahlas'**
  String get recRead;

  /// No description provided for @recConsent.
  ///
  /// In cs, this message translates to:
  /// **'Souhlasím, aby Hajánek z mé nahrávky vytvořil můj hlas. Nahrávka i hlas jsou jen na serveru Hajánka a kdykoli je smažu.'**
  String get recConsent;

  /// No description provided for @recStart.
  ///
  /// In cs, this message translates to:
  /// **'Nahrávat'**
  String get recStart;

  /// No description provided for @recStop.
  ///
  /// In cs, this message translates to:
  /// **'Hotovo'**
  String get recStop;

  /// No description provided for @recReadHint.
  ///
  /// In cs, this message translates to:
  /// **'Při nahrávání se text posouvá s tebou. Ťukni na řádek, který právě čteš, když se rozejdete.'**
  String get recReadHint;

  /// No description provided for @recReadyHint.
  ///
  /// In cs, this message translates to:
  /// **'čti dál, po 30 s se zastaví samo'**
  String get recReadyHint;

  /// No description provided for @recPlay.
  ///
  /// In cs, this message translates to:
  /// **'Poslechnout'**
  String get recPlay;

  /// No description provided for @recPause.
  ///
  /// In cs, this message translates to:
  /// **'Zastavit'**
  String get recPause;

  /// No description provided for @recAgain.
  ///
  /// In cs, this message translates to:
  /// **'Nahrát znovu'**
  String get recAgain;

  /// No description provided for @recUpload.
  ///
  /// In cs, this message translates to:
  /// **'Odeslat'**
  String get recUpload;

  /// No description provided for @recUploading.
  ///
  /// In cs, this message translates to:
  /// **'Odesílám…'**
  String get recUploading;

  /// No description provided for @recNoMic.
  ///
  /// In cs, this message translates to:
  /// **'Bez přístupu k mikrofonu to nejde — povol ho v Nastavení.'**
  String get recNoMic;

  /// No description provided for @recFailed.
  ///
  /// In cs, this message translates to:
  /// **'Nahrávání se nepodařilo. Zkus to prosím znovu.'**
  String get recFailed;

  /// No description provided for @pairTv.
  ///
  /// In cs, this message translates to:
  /// **'Propojit televizi'**
  String get pairTv;

  /// No description provided for @pairTvSub.
  ///
  /// In cs, this message translates to:
  /// **'Tvůj hlas pak bude číst pohádky i v televizi'**
  String get pairTvSub;

  /// No description provided for @pairTvHelp.
  ///
  /// In cs, this message translates to:
  /// **'Na televizi otevři Hajánek → Hlas → Propojit s telefonem. Ukáže se šestimístný kód.'**
  String get pairTvHelp;

  /// No description provided for @pairCode.
  ///
  /// In cs, this message translates to:
  /// **'Kód z televize'**
  String get pairCode;

  /// No description provided for @pairConfirm.
  ///
  /// In cs, this message translates to:
  /// **'Propojit'**
  String get pairConfirm;

  /// No description provided for @pairTvDone.
  ///
  /// In cs, this message translates to:
  /// **'Televize je propojená, hlasy se do ní stáhnou samy.'**
  String get pairTvDone;

  /// No description provided for @pairBadCode.
  ///
  /// In cs, this message translates to:
  /// **'Tenhle kód nesedí nebo už vypršel. Zkontroluj ho na televizi.'**
  String get pairBadCode;

  /// No description provided for @tvVoice.
  ///
  /// In cs, this message translates to:
  /// **'Hlas'**
  String get tvVoice;

  /// No description provided for @tvBackground.
  ///
  /// In cs, this message translates to:
  /// **'Podkres'**
  String get tvBackground;

  /// No description provided for @tvSettings.
  ///
  /// In cs, this message translates to:
  /// **'Nastavení'**
  String get tvSettings;

  /// No description provided for @tvOn.
  ///
  /// In cs, this message translates to:
  /// **'zapnuto'**
  String get tvOn;

  /// No description provided for @tvOff.
  ///
  /// In cs, this message translates to:
  /// **'vypnuto'**
  String get tvOff;

  /// No description provided for @tvPause.
  ///
  /// In cs, this message translates to:
  /// **'Pauza'**
  String get tvPause;

  /// No description provided for @tvResume.
  ///
  /// In cs, this message translates to:
  /// **'Pokračovat'**
  String get tvResume;

  /// No description provided for @tvFavourite.
  ///
  /// In cs, this message translates to:
  /// **'Oblíbená'**
  String get tvFavourite;

  /// No description provided for @tvUnfavourite.
  ///
  /// In cs, this message translates to:
  /// **'Odebrat z oblíbených'**
  String get tvUnfavourite;

  /// No description provided for @tvJukeboxSub.
  ///
  /// In cs, this message translates to:
  /// **'Vyber podkres, hraje bez pohádky'**
  String get tvJukeboxSub;

  /// No description provided for @tvBalance.
  ///
  /// In cs, this message translates to:
  /// **'Hlas ↔ podkres'**
  String get tvBalance;

  /// No description provided for @voiceSystemTv.
  ///
  /// In cs, this message translates to:
  /// **'Hlas televize'**
  String get voiceSystemTv;

  /// No description provided for @voiceSystemTvSub.
  ///
  /// In cs, this message translates to:
  /// **'Bez internetu, pokud televize umí česky'**
  String get voiceSystemTvSub;

  /// No description provided for @voiceParentTvHint.
  ///
  /// In cs, this message translates to:
  /// **'Hlas rodiče se nahrává v telefonu. Propoj televizi s telefonem a hlasy se sem stáhnou samy.'**
  String get voiceParentTvHint;

  /// No description provided for @voiceHintTitleTv.
  ///
  /// In cs, this message translates to:
  /// **'Televize nemá český hlas'**
  String get voiceHintTitleTv;

  /// No description provided for @voiceHintTv.
  ///
  /// In cs, this message translates to:
  /// **'Pohádky přečte hlas rodiče: nahraj ho v telefonu a propoj televizi (Hlas → Propojit s telefonem). Bez něj hraje jen podkres.'**
  String get voiceHintTv;

  /// No description provided for @pairTitle.
  ///
  /// In cs, this message translates to:
  /// **'Propojit s telefonem'**
  String get pairTitle;

  /// No description provided for @pairSub.
  ///
  /// In cs, this message translates to:
  /// **'Hlas rodiče se nahrává v telefonu'**
  String get pairSub;

  /// No description provided for @pairInstructions.
  ///
  /// In cs, this message translates to:
  /// **'V telefonu otevři Hajánek → Hlas → Propojit televizi a zadej kód'**
  String get pairInstructions;

  /// No description provided for @pairWaiting.
  ///
  /// In cs, this message translates to:
  /// **'Čekám na telefon…'**
  String get pairWaiting;

  /// No description provided for @pairDone.
  ///
  /// In cs, this message translates to:
  /// **'Propojeno. Hlasy se teď stahují do televize.'**
  String get pairDone;

  /// No description provided for @pairExpired.
  ///
  /// In cs, this message translates to:
  /// **'Kód vypršel.'**
  String get pairExpired;

  /// No description provided for @pairNewCode.
  ///
  /// In cs, this message translates to:
  /// **'Nový kód'**
  String get pairNewCode;

  /// No description provided for @pairClose.
  ///
  /// In cs, this message translates to:
  /// **'Hotovo'**
  String get pairClose;

  /// No description provided for @minutes.
  ///
  /// In cs, this message translates to:
  /// **'{n} min'**
  String minutes(int n);

  /// No description provided for @detailAge.
  ///
  /// In cs, this message translates to:
  /// **'věk {age}'**
  String detailAge(String age);

  /// No description provided for @playerIntroLeft.
  ///
  /// In cs, this message translates to:
  /// **'Pohádka začne za {left}'**
  String playerIntroLeft(String left);

  /// No description provided for @sectionUvod.
  ///
  /// In cs, this message translates to:
  /// **'Úvod'**
  String get sectionUvod;

  /// No description provided for @sectionVstup.
  ///
  /// In cs, this message translates to:
  /// **'Vstup'**
  String get sectionVstup;

  /// No description provided for @sectionPribeh.
  ///
  /// In cs, this message translates to:
  /// **'Příběh'**
  String get sectionPribeh;

  /// No description provided for @sectionDojezd.
  ///
  /// In cs, this message translates to:
  /// **'Dojezd'**
  String get sectionDojezd;

  /// No description provided for @settingsCatalogVersion.
  ///
  /// In cs, this message translates to:
  /// **'Verze katalogu {v}'**
  String settingsCatalogVersion(int v);

  /// No description provided for @seconds.
  ///
  /// In cs, this message translates to:
  /// **'{n} s'**
  String seconds(int n);

  /// No description provided for @voiceDownloading.
  ///
  /// In cs, this message translates to:
  /// **'Stahuji hlas: {done} z {total} vět'**
  String voiceDownloading(int done, int total);

  /// No description provided for @voiceDeleteConfirm.
  ///
  /// In cs, this message translates to:
  /// **'Smazat hlas „{name}“? Nahrávka i všechny věty se smažou z telefonu i ze serveru.'**
  String voiceDeleteConfirm(String name);

  /// No description provided for @recMinHint.
  ///
  /// In cs, this message translates to:
  /// **'dokončit jde po {s} s'**
  String recMinHint(int s);

  /// No description provided for @balanceVoiceOnly.
  ///
  /// In cs, this message translates to:
  /// **'Jen hlas'**
  String get balanceVoiceOnly;

  /// No description provided for @balanceMoreVoice.
  ///
  /// In cs, this message translates to:
  /// **'Víc hlasu'**
  String get balanceMoreVoice;

  /// No description provided for @balanceEven.
  ///
  /// In cs, this message translates to:
  /// **'Vyrovnaně'**
  String get balanceEven;

  /// No description provided for @balanceMoreBackground.
  ///
  /// In cs, this message translates to:
  /// **'Víc podkresu'**
  String get balanceMoreBackground;

  /// No description provided for @balanceBackgroundOnly.
  ///
  /// In cs, this message translates to:
  /// **'Jen podkres'**
  String get balanceBackgroundOnly;

  /// No description provided for @languageTitle.
  ///
  /// In cs, this message translates to:
  /// **'Jazyk'**
  String get languageTitle;

  /// No description provided for @languageSub.
  ///
  /// In cs, this message translates to:
  /// **'Jazyk aplikace, pohádek i hlasu'**
  String get languageSub;

  /// No description provided for @languageSystem.
  ///
  /// In cs, this message translates to:
  /// **'Podle telefonu'**
  String get languageSystem;

  /// No description provided for @playerChannel.
  ///
  /// In cs, this message translates to:
  /// **'Přehrávání'**
  String get playerChannel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['cs'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'cs':
      return AppLocalizationsCs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
