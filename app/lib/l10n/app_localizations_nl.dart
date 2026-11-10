// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get homeJukebox => 'Geluidenjukebox';

  @override
  String get homeJukeboxSub => 'Alleen achtergrondgeluid, zonder sprookje';

  @override
  String get homeTales => 'Sprookjes';

  @override
  String get homeNowPlaying => 'Speelt nu';

  @override
  String get detailVoice => 'Stem';

  @override
  String get detailNoScript => 'Het sprookje kon niet worden geladen.';

  @override
  String get detailBackground => 'Achtergrond';

  @override
  String get detailRecommended => 'Aanbevolen';

  @override
  String get detailNoBackground => 'Geen achtergrond';

  @override
  String get detailRitual => '‘Welterusten’-ritueel';

  @override
  String get detailRitualSub =>
      'Eerst alleen achtergrond, en na het sprookje speelt die nog even door';

  @override
  String get detailPlay => 'Afspelen';

  @override
  String get detailFavourite => 'Favoriet';

  @override
  String get playerIntro => 'Alleen achtergrond…';

  @override
  String get playerStartNow => 'Nu beginnen';

  @override
  String get playerVoice => 'Sprookje';

  @override
  String get playerTail => 'Achtergrond sterft weg';

  @override
  String get playerFadeOut => 'Wordt stil…';

  @override
  String get playerDone => 'Welterusten';

  @override
  String get playerMixer => 'Jukebox';

  @override
  String get playerBalance => 'Stem ↔ achtergrond';

  @override
  String get playerBackground => 'Achtergrond';

  @override
  String get playerStop => 'Stoppen';

  @override
  String get playerNothing => 'Er speelt niets';

  @override
  String get mixerTitle => 'Geluidenjukebox';

  @override
  String get mixerMain => 'Hoofdgeluid';

  @override
  String get mixerSecondary => 'Extra geluid';

  @override
  String get mixerAddLayer => 'Laag toevoegen';

  @override
  String get mixerPresets => 'Opgeslagen mixen';

  @override
  String get mixerSavePreset => 'Mix opslaan';

  @override
  String get mixerPresetName => 'Naam van de mix';

  @override
  String get mixerSave => 'Opslaan';

  @override
  String get mixerCancel => 'Annuleren';

  @override
  String get mixerDeletePreset => 'Mix verwijderen?';

  @override
  String get mixerDelete => 'Verwijderen';

  @override
  String get mixerRemoveLayer => 'Laag verwijderen';

  @override
  String get mixerGroupNature => 'Natuurgeluiden';

  @override
  String get mixerGroupMusic => 'Slaapliedjes';

  @override
  String get timerTitle => 'Timer';

  @override
  String get timerOff => 'Uit';

  @override
  String get timerEndOfTale => 'Einde van het sprookje';

  @override
  String get settingsTitle => 'Instellingen';

  @override
  String get settingsBreathing => 'Ademende cirkel';

  @override
  String get settingsBreathingSub => 'De enige beweging op het afspeelscherm';

  @override
  String get settingsIntro => 'Achtergrond vóór het sprookje (ritueel)';

  @override
  String get settingsTail => 'Achtergrond na het sprookje (ritueel)';

  @override
  String get settingsTimer => 'Standaardtimer';

  @override
  String get settingsCatalog => 'Catalogus';

  @override
  String get settingsCheckUpdates => 'Zoeken naar updates';

  @override
  String get settingsChecking => 'Bezig met zoeken…';

  @override
  String get settingsUpToDate => 'De catalogus is bijgewerkt';

  @override
  String get settingsUpdated => 'Catalogus bijgewerkt';

  @override
  String get settingsOffline => 'Geen verbinding — alles werkt offline';

  @override
  String get settingsVoice => 'Stem';

  @override
  String get settingsVocative => 'Hoe je je kind noemt';

  @override
  String get settingsVocativeSub =>
      'De naam waarmee je je kind aanspreekt, bijv. Saar. Wordt nog niet gebruikt.';

  @override
  String get settingsVocativeNone => 'Niet ingesteld';

  @override
  String get settingsPrivacy =>
      'Geen account, geen analyse. Het netwerk wordt alleen gebruikt om de catalogus bij te werken.';

  @override
  String get settingsPrivacyCloning =>
      'Geen account, geen analyse. Het netwerk wordt alleen gebruikt om de catalogus bij te werken en voor je opgenomen stem.';

  @override
  String get voiceTitle => 'Stem';

  @override
  String get voiceSystem => 'Stem van de telefoon';

  @override
  String get voiceSystemSub => 'Werkt meteen, zonder internet';

  @override
  String get voiceRecord => 'Mijn stem opnemen';

  @override
  String get voiceBeta =>
      'Gratis proefversie. Het klaarmaken van je stem duurt een paar uur.';

  @override
  String get voicePending =>
      'Je stem wordt klaargemaakt en is morgenochtend klaar';

  @override
  String get voiceReady => 'Klaar';

  @override
  String get voiceWaiting => 'Je stem is klaar, wachten op de eerste zinnen';

  @override
  String get voiceFailed =>
      'Je stem kon niet worden gemaakt. Probeer opnieuw op te nemen.';

  @override
  String get voiceDelete => 'Stem verwijderen';

  @override
  String get voiceCancel => 'Annuleren';

  @override
  String get voiceMissingClips =>
      'Zinnen die nog niet zijn gedownload, worden voorlopig door de stem van de telefoon voorgelezen.';

  @override
  String get voiceHintTitle => 'Je telefoon heeft geen Engelse stem';

  @override
  String get voiceHintIos =>
      'Installeer er een via Instellingen → Toegankelijkheid → Gesproken materiaal → Stemmen → Engels (liefst een verbeterde of premium stem).';

  @override
  String get voiceHintAndroid =>
      'Installeer er een via Instellingen → Tekst-naar-spraakuitvoer → Google → Spraakgegevens installeren → Engels.';

  @override
  String get voiceHintOk => 'Begrepen';

  @override
  String get recTitle => 'Mijn stem opnemen';

  @override
  String get recName => 'Je naam';

  @override
  String get recNameHint => 'bijv. Anne';

  @override
  String get recTips => 'Voordat je begint';

  @override
  String get recRead => 'Lees hardop voor';

  @override
  String get recConsent =>
      'Ik ga ermee akkoord dat Hajánek mijn stem maakt op basis van mijn opname. De opname en de stem staan alleen op de server van Hajánek en ik kan ze op elk moment verwijderen.';

  @override
  String get recStart => 'Opnemen';

  @override
  String get recStop => 'Klaar';

  @override
  String get recReadHint =>
      'Tijdens het opnemen loopt de tekst met je mee. Loopt hij voor of achter, tik dan op de regel die je aan het lezen bent.';

  @override
  String get recReadyHint => 'lees verder, na 30 s stopt het vanzelf';

  @override
  String get recPlay => 'Beluisteren';

  @override
  String get recPause => 'Stoppen';

  @override
  String get recAgain => 'Opnieuw opnemen';

  @override
  String get recUpload => 'Versturen';

  @override
  String get recUploading => 'Bezig met versturen…';

  @override
  String get recNoMic =>
      'Hiervoor is toegang tot de microfoon nodig — sta die toe in Instellingen.';

  @override
  String get recFailed => 'De opname is mislukt. Probeer het opnieuw.';

  @override
  String get pairTv => 'Een tv koppelen';

  @override
  String get pairTvSub => 'Dan leest je stem de sprookjes ook op de tv voor';

  @override
  String get pairTvHelp =>
      'Open op de tv Hajánek → Stem → Koppelen met telefoon. Er verschijnt een code van zes cijfers.';

  @override
  String get pairCode => 'Code van de tv';

  @override
  String get pairConfirm => 'Koppelen';

  @override
  String get pairTvDone =>
      'De tv is gekoppeld. De stemmen worden er vanzelf naartoe gedownload.';

  @override
  String get pairBadCode =>
      'Deze code klopt niet of is verlopen. Controleer hem op de tv.';

  @override
  String get tvVoice => 'Stem';

  @override
  String get tvBackground => 'Achtergrond';

  @override
  String get tvSettings => 'Instellingen';

  @override
  String get tvOn => 'aan';

  @override
  String get tvOff => 'uit';

  @override
  String get tvPause => 'Pauze';

  @override
  String get tvResume => 'Doorgaan';

  @override
  String get tvFavourite => 'Favoriet';

  @override
  String get tvUnfavourite => 'Verwijderen uit favorieten';

  @override
  String get tvJukeboxSub => 'Kies een achtergrond, die speelt zonder sprookje';

  @override
  String get tvBalance => 'Stem ↔ achtergrond';

  @override
  String get voiceSystemTv => 'Stem van de tv';

  @override
  String get voiceSystemTvSub => 'Zonder internet, als de tv Engels spreekt';

  @override
  String get voiceParentTvHint =>
      'De stem van een ouder wordt op de telefoon opgenomen. Koppel de tv aan de telefoon en de stemmen worden hier vanzelf gedownload.';

  @override
  String get voiceHintTitleTv => 'De tv heeft geen Engelse stem';

  @override
  String get voiceHintTv =>
      'De stem van een ouder kan de sprookjes voorlezen: neem hem op met de telefoon en koppel de tv (Stem → Koppelen met telefoon). Zonder die stem speelt alleen de achtergrond.';

  @override
  String get pairTitle => 'Koppelen met telefoon';

  @override
  String get pairSub => 'De stem van een ouder wordt op de telefoon opgenomen';

  @override
  String get pairInstructions =>
      'Open op de telefoon Hajánek → Stem → Een tv koppelen en voer de code in';

  @override
  String get pairWaiting => 'Wachten op de telefoon…';

  @override
  String get pairDone =>
      'Gekoppeld. De stemmen worden nu naar de tv gedownload.';

  @override
  String get pairExpired => 'De code is verlopen.';

  @override
  String get pairNewCode => 'Nieuwe code';

  @override
  String get pairClose => 'Klaar';

  @override
  String minutes(int n) {
    return '$n min';
  }

  @override
  String detailAge(String age) {
    return 'leeftijd $age';
  }

  @override
  String playerIntroLeft(String left) {
    return 'Het sprookje begint over $left';
  }

  @override
  String get sectionUvod => 'Tot rust komen';

  @override
  String get sectionVstup => 'Het sprookje in';

  @override
  String get sectionPribeh => 'Verhaal';

  @override
  String get sectionDojezd => 'Uitdoven';

  @override
  String settingsCatalogVersion(int v) {
    return 'Catalogusversie $v';
  }

  @override
  String seconds(int n) {
    return '$n s';
  }

  @override
  String voiceDownloading(int done, int total) {
    return 'Stem downloaden: $done van $total zinnen';
  }

  @override
  String voiceDeleteConfirm(String name) {
    return 'De stem ‘$name’ verwijderen? De opname en alle zinnen worden van de telefoon en van de server verwijderd.';
  }

  @override
  String recMinHint(int s) {
    return 'je kunt stoppen na $s s';
  }

  @override
  String get balanceVoiceOnly => 'Alleen stem';

  @override
  String get balanceMoreVoice => 'Meer stem';

  @override
  String get balanceEven => 'Gelijk';

  @override
  String get balanceMoreBackground => 'Meer achtergrond';

  @override
  String get balanceBackgroundOnly => 'Alleen achtergrond';

  @override
  String get languageTitle => 'Taal';

  @override
  String get languageSub => 'Taal van de app, de sprookjes en de stem';

  @override
  String get languageSystem => 'Zoals de telefoon';

  @override
  String get playerChannel => 'Afspelen';

  @override
  String get languageTalesFallback =>
      'De sprookjes zijn nog niet in deze taal, dus ze worden in het Engels afgespeeld.';
}
