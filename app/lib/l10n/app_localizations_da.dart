// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Danish (`da`).
class AppLocalizationsDa extends AppLocalizations {
  AppLocalizationsDa([String locale = 'da']) : super(locale);

  @override
  String get homeJukebox => 'Lydjukebox';

  @override
  String get homeJukeboxSub => 'Kun baggrundslyde, uden eventyr';

  @override
  String get homeTales => 'Eventyr';

  @override
  String get homeNowPlaying => 'Spiller nu';

  @override
  String get detailVoice => 'Stemme';

  @override
  String get detailNoScript => 'Eventyret kunne ikke indlæses.';

  @override
  String get detailBackground => 'Baggrund';

  @override
  String get detailRecommended => 'Anbefalet';

  @override
  String get detailNoBackground => 'Ingen baggrund';

  @override
  String get detailRitual => '“Godnat”-ritual';

  @override
  String get detailRitualSub =>
      'Først kun baggrund, og den spiller lidt videre efter eventyret';

  @override
  String get detailPlay => 'Afspil';

  @override
  String get detailFavourite => 'Favorit';

  @override
  String get playerIntro => 'Kun baggrund…';

  @override
  String get playerStartNow => 'Start nu';

  @override
  String get playerVoice => 'Eventyr';

  @override
  String get playerTail => 'Baggrunden toner ud';

  @override
  String get playerFadeOut => 'Bliver stille…';

  @override
  String get playerDone => 'Godnat';

  @override
  String get playerMixer => 'Jukebox';

  @override
  String get playerBalance => 'Stemme ↔ baggrund';

  @override
  String get playerBackground => 'Baggrund';

  @override
  String get playerStop => 'Stop';

  @override
  String get playerNothing => 'Intet spiller';

  @override
  String get mixerTitle => 'Lydjukebox';

  @override
  String get mixerMain => 'Hovedlyd';

  @override
  String get mixerSecondary => 'Ekstra lyd';

  @override
  String get mixerAddLayer => 'Tilføj lag';

  @override
  String get mixerPresets => 'Gemte blandinger';

  @override
  String get mixerSavePreset => 'Gem blanding';

  @override
  String get mixerPresetName => 'Navn på blanding';

  @override
  String get mixerSave => 'Gem';

  @override
  String get mixerCancel => 'Annuller';

  @override
  String get mixerDeletePreset => 'Slet blanding?';

  @override
  String get mixerDelete => 'Slet';

  @override
  String get mixerRemoveLayer => 'Fjern lag';

  @override
  String get mixerGroupNature => 'Naturlyde';

  @override
  String get mixerGroupMusic => 'Vuggeviser';

  @override
  String get timerTitle => 'Timer';

  @override
  String get timerOff => 'Fra';

  @override
  String get timerEndOfTale => 'Når eventyret slutter';

  @override
  String get settingsTitle => 'Indstillinger';

  @override
  String get settingsBreathing => 'Åndende cirkel';

  @override
  String get settingsBreathingSub =>
      'Den eneste bevægelse på afspilningsskærmen';

  @override
  String get settingsIntro => 'Baggrund før eventyret (ritual)';

  @override
  String get settingsTail => 'Baggrund efter eventyret (ritual)';

  @override
  String get settingsTimer => 'Standardtimer';

  @override
  String get settingsCatalog => 'Katalog';

  @override
  String get settingsCheckUpdates => 'Søg efter opdateringer';

  @override
  String get settingsChecking => 'Søger…';

  @override
  String get settingsUpToDate => 'Kataloget er opdateret';

  @override
  String get settingsUpdated => 'Kataloget er opdateret nu';

  @override
  String get settingsOffline => 'Ingen forbindelse — alt virker offline';

  @override
  String get settingsVoice => 'Stemme';

  @override
  String get settingsVocative => 'Hvad du kalder dit barn';

  @override
  String get settingsVocativeSub =>
      'Det navn, du kalder dit barn, f.eks. Ida. Bruges ikke endnu.';

  @override
  String get settingsVocativeNone => 'Ikke valgt';

  @override
  String get settingsPrivacy =>
      'Ingen konto, ingen analyse. Netværket bruges kun til at opdatere kataloget.';

  @override
  String get settingsPrivacyCloning =>
      'Ingen konto, ingen analyse. Netværket bruges kun til at opdatere kataloget og til din indspillede stemme.';

  @override
  String get voiceTitle => 'Stemme';

  @override
  String get voiceSystem => 'Telefonens stemme';

  @override
  String get voiceSystemSub => 'Virker med det samme, uden internet';

  @override
  String get voiceRecord => 'Indspil min stemme';

  @override
  String get voiceBeta =>
      'Gratis prøve. Din stemme tager et par timer at gøre klar.';

  @override
  String get voicePending =>
      'Din stemme bliver gjort klar og er færdig i morgen tidlig';

  @override
  String get voiceReady => 'Klar';

  @override
  String get voiceWaiting =>
      'Din stemme er klar, venter på de første sætninger';

  @override
  String get voiceFailed =>
      'Din stemme kunne ikke laves. Prøv at indspille igen.';

  @override
  String get voiceDelete => 'Slet stemme';

  @override
  String get voiceCancel => 'Annuller';

  @override
  String get voiceMissingClips =>
      'Sætninger, der ikke er hentet endnu, læses indtil videre af telefonens stemme.';

  @override
  String get voiceHintTitle => 'Telefonen har ingen engelsk stemme';

  @override
  String get voiceHintIos =>
      'Installer en under Indstillinger → Tilgængelighed → Oplæst indhold → Stemmer → Engelsk (helst en forbedret eller premium-stemme).';

  @override
  String get voiceHintAndroid =>
      'Installer en under Indstillinger → Oplæsning → Google → Installer stemmedata → Engelsk.';

  @override
  String get voiceHintOk => 'Forstået';

  @override
  String get recTitle => 'Indspil min stemme';

  @override
  String get recName => 'Dit navn';

  @override
  String get recNameHint => 'f.eks. Anne';

  @override
  String get recTips => 'Før du starter';

  @override
  String get recRead => 'Læs højt';

  @override
  String get recConsent =>
      'Jeg giver Hajánek lov til at lave min stemme ud fra min optagelse. Optagelsen og stemmen gemmes kun på Hajáneks server, og jeg kan slette dem når som helst.';

  @override
  String get recStart => 'Optag';

  @override
  String get recStop => 'Færdig';

  @override
  String get recReadHint =>
      'Mens du optager, følger teksten med dig. Hvis den kommer foran eller bagud, så tryk på den linje, du læser.';

  @override
  String get recReadyHint => 'læs videre, den stopper selv efter 30 s';

  @override
  String get recPlay => 'Lyt';

  @override
  String get recPause => 'Stop';

  @override
  String get recAgain => 'Optag igen';

  @override
  String get recUpload => 'Send';

  @override
  String get recUploading => 'Sender…';

  @override
  String get recNoMic =>
      'Det kræver adgang til mikrofonen — tillad det i Indstillinger.';

  @override
  String get recFailed => 'Optagelsen lykkedes ikke. Prøv igen.';

  @override
  String get pairTv => 'Forbind et tv';

  @override
  String get pairTvSub => 'Så læser din stemme også eventyrene på tv’et';

  @override
  String get pairTvHelp =>
      'Åbn Hajánek på tv’et → Stemme → Forbind med telefon. Der vises en sekscifret kode.';

  @override
  String get pairCode => 'Kode fra tv’et';

  @override
  String get pairConfirm => 'Forbind';

  @override
  String get pairTvDone =>
      'Tv’et er forbundet. Stemmerne hentes selv ned på det.';

  @override
  String get pairBadCode =>
      'Koden passer ikke eller er udløbet. Tjek den på tv’et.';

  @override
  String get tvVoice => 'Stemme';

  @override
  String get tvBackground => 'Baggrund';

  @override
  String get tvSettings => 'Indstillinger';

  @override
  String get tvOn => 'til';

  @override
  String get tvOff => 'fra';

  @override
  String get tvPause => 'Pause';

  @override
  String get tvResume => 'Fortsæt';

  @override
  String get tvFavourite => 'Favorit';

  @override
  String get tvUnfavourite => 'Fjern fra favoritter';

  @override
  String get tvJukeboxSub => 'Vælg en baggrund, den spiller uden eventyr';

  @override
  String get tvBalance => 'Stemme ↔ baggrund';

  @override
  String get voiceSystemTv => 'Tv’ets stemme';

  @override
  String get voiceSystemTvSub => 'Uden internet, hvis tv’et taler engelsk';

  @override
  String get voiceParentTvHint =>
      'En forælders stemme indspilles på telefonen. Forbind tv’et med telefonen, så hentes stemmerne selv herind.';

  @override
  String get voiceHintTitleTv => 'Tv’et har ingen engelsk stemme';

  @override
  String get voiceHintTv =>
      'En forælders stemme kan læse eventyrene: indspil den på telefonen og forbind tv’et (Stemme → Forbind med telefon). Uden den spiller kun baggrunden.';

  @override
  String get pairTitle => 'Forbind med telefon';

  @override
  String get pairSub => 'En forælders stemme indspilles på telefonen';

  @override
  String get pairInstructions =>
      'Åbn Hajánek på telefonen → Stemme → Forbind et tv, og indtast koden';

  @override
  String get pairWaiting => 'Venter på telefonen…';

  @override
  String get pairDone => 'Forbundet. Stemmerne hentes nu ned på tv’et.';

  @override
  String get pairExpired => 'Koden er udløbet.';

  @override
  String get pairNewCode => 'Ny kode';

  @override
  String get pairClose => 'Færdig';

  @override
  String minutes(int n) {
    return '$n min';
  }

  @override
  String detailAge(String age) {
    return 'alder $age';
  }

  @override
  String playerIntroLeft(String left) {
    return 'Eventyret starter om $left';
  }

  @override
  String get sectionUvod => 'Falde til ro';

  @override
  String get sectionVstup => 'Ind i eventyret';

  @override
  String get sectionPribeh => 'Historien';

  @override
  String get sectionDojezd => 'Nedtrapning';

  @override
  String settingsCatalogVersion(int v) {
    return 'Katalogversion $v';
  }

  @override
  String seconds(int n) {
    return '$n s';
  }

  @override
  String voiceDownloading(int done, int total) {
    return 'Henter stemme: $done af $total sætninger';
  }

  @override
  String voiceDeleteConfirm(String name) {
    return 'Slet stemmen “$name”? Optagelsen og alle sætninger slettes fra telefonen og fra serveren.';
  }

  @override
  String recMinHint(int s) {
    return 'du kan stoppe efter $s s';
  }

  @override
  String get balanceVoiceOnly => 'Kun stemme';

  @override
  String get balanceMoreVoice => 'Mere stemme';

  @override
  String get balanceEven => 'Lige meget';

  @override
  String get balanceMoreBackground => 'Mere baggrund';

  @override
  String get balanceBackgroundOnly => 'Kun baggrund';

  @override
  String get languageTitle => 'Sprog';

  @override
  String get languageSub => 'Sprog for appen, eventyrene og stemmen';

  @override
  String get languageSystem => 'Som telefonen';

  @override
  String get playerChannel => 'Afspilning';

  @override
  String get languageTalesFallback =>
      'Eventyrene findes ikke på dette sprog endnu, så de spiller på engelsk.';
}
