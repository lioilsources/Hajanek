// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get homeJukebox => 'Hangzenegép';

  @override
  String get homeJukeboxSub => 'Csak háttérhangok, mese nélkül';

  @override
  String get homeTales => 'Mesék';

  @override
  String get homeNowPlaying => 'Most szól';

  @override
  String get detailVoice => 'Hang';

  @override
  String get detailNoScript => 'A mesét nem sikerült betölteni.';

  @override
  String get detailBackground => 'Háttér';

  @override
  String get detailRecommended => 'Ajánlott';

  @override
  String get detailNoBackground => 'Nincs háttér';

  @override
  String get detailRitual => '„Jó éjszakát” szertartás';

  @override
  String get detailRitualSub =>
      'Előbb csak a háttér szól, és a mese után még egy darabig folytatódik';

  @override
  String get detailPlay => 'Lejátszás';

  @override
  String get detailFavourite => 'Kedvenc';

  @override
  String get playerIntro => 'Csak háttér…';

  @override
  String get playerStartNow => 'Indítás most';

  @override
  String get playerVoice => 'Mese';

  @override
  String get playerTail => 'A háttér elhalkul';

  @override
  String get playerFadeOut => 'Elcsendesedik…';

  @override
  String get playerDone => 'Jó éjszakát';

  @override
  String get playerMixer => 'Zenegép';

  @override
  String get playerBalance => 'Hang ↔ háttér';

  @override
  String get playerBackground => 'Háttér';

  @override
  String get playerStop => 'Leállítás';

  @override
  String get playerNothing => 'Semmi sem szól';

  @override
  String get mixerTitle => 'Hangzenegép';

  @override
  String get mixerMain => 'Fő hang';

  @override
  String get mixerSecondary => 'Kiegészítő hang';

  @override
  String get mixerAddLayer => 'Réteg hozzáadása';

  @override
  String get mixerPresets => 'Mentett keverékek';

  @override
  String get mixerSavePreset => 'Keverék mentése';

  @override
  String get mixerPresetName => 'A keverék neve';

  @override
  String get mixerSave => 'Mentés';

  @override
  String get mixerCancel => 'Mégse';

  @override
  String get mixerDeletePreset => 'Törlöd a keveréket?';

  @override
  String get mixerDelete => 'Törlés';

  @override
  String get mixerRemoveLayer => 'Réteg eltávolítása';

  @override
  String get mixerGroupNature => 'Természethangok';

  @override
  String get mixerGroupMusic => 'Altatók';

  @override
  String get timerTitle => 'Időzítő';

  @override
  String get timerOff => 'Ki';

  @override
  String get timerEndOfTale => 'A mese végén';

  @override
  String get settingsTitle => 'Beállítások';

  @override
  String get settingsBreathing => 'Lélegző kör';

  @override
  String get settingsBreathingSub =>
      'Az egyetlen mozgás a lejátszó képernyőjén';

  @override
  String get settingsIntro => 'Háttér a mese előtt (szertartás)';

  @override
  String get settingsTail => 'Háttér a mese után (szertartás)';

  @override
  String get settingsTimer => 'Alapértelmezett időzítő';

  @override
  String get settingsCatalog => 'Katalógus';

  @override
  String get settingsCheckUpdates => 'Frissítések keresése';

  @override
  String get settingsChecking => 'Ellenőrzés…';

  @override
  String get settingsUpToDate => 'A katalógus naprakész';

  @override
  String get settingsUpdated => 'A katalógus frissült';

  @override
  String get settingsOffline => 'Nincs kapcsolat — minden működik offline is';

  @override
  String get settingsVoice => 'Hang';

  @override
  String get settingsVocative => 'Hogyan szólítod a gyereket';

  @override
  String get settingsVocativeSub =>
      'Ahogy a gyerekedet szólítod, pl. Panni. Még nincs használatban.';

  @override
  String get settingsVocativeNone => 'Nincs megadva';

  @override
  String get settingsPrivacy =>
      'Nincs fiók, nincs analitika. A hálózatot csak a katalógus frissítésére használjuk.';

  @override
  String get settingsPrivacyCloning =>
      'Nincs fiók, nincs analitika. A hálózatot csak a katalógus frissítésére és a felvett hangodhoz használjuk.';

  @override
  String get voiceTitle => 'Hang';

  @override
  String get voiceSystem => 'A telefon hangja';

  @override
  String get voiceSystemSub => 'Azonnal működik, internet nélkül';

  @override
  String get voiceRecord => 'Saját hangom felvétele';

  @override
  String get voiceBeta =>
      'Ingyenes próba. A hangod elkészítése néhány órát vesz igénybe.';

  @override
  String get voicePending => 'A hangod készül, reggelre elkészül';

  @override
  String get voiceReady => 'Kész';

  @override
  String get voiceWaiting => 'A hangod kész, várakozás az első mondatokra';

  @override
  String get voiceFailed =>
      'A hangodat nem sikerült létrehozni. Próbáld újra felvenni.';

  @override
  String get voiceDelete => 'Hang törlése';

  @override
  String get voiceCancel => 'Mégse';

  @override
  String get voiceMissingClips =>
      'A még le nem töltött mondatokat egyelőre a telefon hangja olvassa fel.';

  @override
  String get voiceHintTitle => 'A telefonon nincs angol hang';

  @override
  String get voiceHintIos =>
      'Telepíts egyet: Beállítások → Kisegítő lehetőségek → Felolvasott tartalom → Hangok → Angol (lehetőleg továbbfejlesztett vagy prémium hangot).';

  @override
  String get voiceHintAndroid =>
      'Telepíts egyet: Beállítások → Szövegfelolvasó → Google → Hangadatok telepítése → Angol.';

  @override
  String get voiceHintOk => 'Értem';

  @override
  String get recTitle => 'Saját hangom felvétele';

  @override
  String get recName => 'A neved';

  @override
  String get recNameHint => 'pl. Anna';

  @override
  String get recTips => 'Mielőtt elkezded';

  @override
  String get recRead => 'Olvasd fel hangosan';

  @override
  String get recConsent =>
      'Hozzájárulok, hogy a Hajánek a felvételemből elkészítse a hangomat. A felvétel és a hang csak a Hajánek szerverén van, és bármikor törölhetem őket.';

  @override
  String get recStart => 'Felvétel';

  @override
  String get recStop => 'Kész';

  @override
  String get recReadHint =>
      'Felvétel közben a szöveg veled halad. Ha előreszalad vagy lemarad, koppints arra a sorra, amelyet éppen olvasol.';

  @override
  String get recReadyHint => 'olvass tovább, 30 mp után magától leáll';

  @override
  String get recPlay => 'Meghallgatás';

  @override
  String get recPause => 'Leállítás';

  @override
  String get recAgain => 'Újra felvétel';

  @override
  String get recUpload => 'Küldés';

  @override
  String get recUploading => 'Küldés…';

  @override
  String get recNoMic =>
      'Ehhez hozzáférés kell a mikrofonhoz — engedélyezd a Beállításokban.';

  @override
  String get recFailed => 'A felvétel nem sikerült. Próbáld újra.';

  @override
  String get pairTv => 'Tévé csatlakoztatása';

  @override
  String get pairTvSub => 'Így a hangod a tévén is felolvassa a meséket';

  @override
  String get pairTvHelp =>
      'A tévén nyisd meg: Hajánek → Hang → Csatlakozás telefonhoz. Megjelenik egy hatjegyű kód.';

  @override
  String get pairCode => 'Kód a tévéről';

  @override
  String get pairConfirm => 'Csatlakoztatás';

  @override
  String get pairTvDone =>
      'A tévé csatlakoztatva. A hangok maguktól letöltődnek rá.';

  @override
  String get pairBadCode =>
      'Ez a kód nem egyezik vagy lejárt. Ellenőrizd a tévén.';

  @override
  String get tvVoice => 'Hang';

  @override
  String get tvBackground => 'Háttér';

  @override
  String get tvSettings => 'Beállítások';

  @override
  String get tvOn => 'be';

  @override
  String get tvOff => 'ki';

  @override
  String get tvPause => 'Szünet';

  @override
  String get tvResume => 'Folytatás';

  @override
  String get tvFavourite => 'Kedvenc';

  @override
  String get tvUnfavourite => 'Eltávolítás a kedvencek közül';

  @override
  String get tvJukeboxSub => 'Válassz hátteret, mese nélkül szól';

  @override
  String get tvBalance => 'Hang ↔ háttér';

  @override
  String get voiceSystemTv => 'A tévé hangja';

  @override
  String get voiceSystemTvSub => 'Internet nélkül, ha a tévé beszél angolul';

  @override
  String get voiceParentTvHint =>
      'A szülő hangját a telefonon kell felvenni. Csatlakoztasd a tévét a telefonhoz, és a hangok maguktól letöltődnek ide.';

  @override
  String get voiceHintTitleTv => 'A tévén nincs angol hang';

  @override
  String get voiceHintTv =>
      'A meséket a szülő hangja is felolvashatja: vedd fel a telefonon, és csatlakoztasd a tévét (Hang → Csatlakozás telefonhoz). Nélküle csak a háttér szól.';

  @override
  String get pairTitle => 'Csatlakozás telefonhoz';

  @override
  String get pairSub => 'A szülő hangját a telefonon kell felvenni';

  @override
  String get pairInstructions =>
      'A telefonon nyisd meg: Hajánek → Hang → Tévé csatlakoztatása, és írd be a kódot';

  @override
  String get pairWaiting => 'Várakozás a telefonra…';

  @override
  String get pairDone => 'Csatlakoztatva. A hangok most töltődnek le a tévére.';

  @override
  String get pairExpired => 'A kód lejárt.';

  @override
  String get pairNewCode => 'Új kód';

  @override
  String get pairClose => 'Kész';

  @override
  String minutes(int n) {
    return '$n perc';
  }

  @override
  String detailAge(String age) {
    return '$age éves kortól';
  }

  @override
  String playerIntroLeft(String left) {
    return 'A mese $left múlva kezdődik';
  }

  @override
  String get sectionUvod => 'Elhelyezkedés';

  @override
  String get sectionVstup => 'Be a mesébe';

  @override
  String get sectionPribeh => 'Történet';

  @override
  String get sectionDojezd => 'Lecsendesedés';

  @override
  String settingsCatalogVersion(int v) {
    return 'Katalógusverzió: $v';
  }

  @override
  String seconds(int n) {
    return '$n mp';
  }

  @override
  String voiceDownloading(int done, int total) {
    return 'Hang letöltése: $done/$total mondat';
  }

  @override
  String voiceDeleteConfirm(String name) {
    return 'Törlöd a(z) „$name” hangot? A felvétel és minden mondat törlődik a telefonról és a szerverről.';
  }

  @override
  String recMinHint(int s) {
    return '$s mp után befejezheted';
  }

  @override
  String get balanceVoiceOnly => 'Csak hang';

  @override
  String get balanceMoreVoice => 'Több hang';

  @override
  String get balanceEven => 'Kiegyenlített';

  @override
  String get balanceMoreBackground => 'Több háttér';

  @override
  String get balanceBackgroundOnly => 'Csak háttér';

  @override
  String get languageTitle => 'Nyelv';

  @override
  String get languageSub => 'Az alkalmazás, a mesék és a hang nyelve';

  @override
  String get languageSystem => 'A telefon szerint';

  @override
  String get playerChannel => 'Lejátszás';

  @override
  String get languageTalesFallback =>
      'A mesék még nincsenek meg ezen a nyelven, ezért angolul szólnak.';
}
