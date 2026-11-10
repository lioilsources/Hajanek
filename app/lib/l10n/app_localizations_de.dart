// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get homeJukebox => 'Klang-Jukebox';

  @override
  String get homeJukeboxSub => 'Nur Klänge, ohne Märchen';

  @override
  String get homeTales => 'Märchen';

  @override
  String get homeNowPlaying => 'Läuft gerade';

  @override
  String get detailVoice => 'Stimme';

  @override
  String get detailNoScript => 'Das Märchen konnte nicht geladen werden.';

  @override
  String get detailBackground => 'Hintergrund';

  @override
  String get detailRecommended => 'Empfohlen';

  @override
  String get detailNoBackground => 'Ohne Hintergrund';

  @override
  String get detailRitual => '„Gute Nacht“-Ritual';

  @override
  String get detailRitualSub =>
      'Erst nur Hintergrund, nach dem Märchen klingt er noch eine Weile nach';

  @override
  String get detailPlay => 'Abspielen';

  @override
  String get detailFavourite => 'Favorit';

  @override
  String get playerIntro => 'Nur Hintergrund…';

  @override
  String get playerStartNow => 'Jetzt beginnen';

  @override
  String get playerVoice => 'Märchen';

  @override
  String get playerTail => 'Hintergrund klingt nach';

  @override
  String get playerFadeOut => 'Wird leiser…';

  @override
  String get playerDone => 'Gute Nacht';

  @override
  String get playerMixer => 'Jukebox';

  @override
  String get playerBalance => 'Stimme ↔ Hintergrund';

  @override
  String get playerBackground => 'Hintergrund';

  @override
  String get playerStop => 'Stopp';

  @override
  String get playerNothing => 'Es läuft nichts';

  @override
  String get mixerTitle => 'Klang-Jukebox';

  @override
  String get mixerMain => 'Hauptklang';

  @override
  String get mixerSecondary => 'Zweiter Klang';

  @override
  String get mixerAddLayer => 'Ebene hinzufügen';

  @override
  String get mixerPresets => 'Voreinstellungen';

  @override
  String get mixerSavePreset => 'Voreinstellung speichern';

  @override
  String get mixerPresetName => 'Name der Voreinstellung';

  @override
  String get mixerSave => 'Speichern';

  @override
  String get mixerCancel => 'Abbrechen';

  @override
  String get mixerDeletePreset => 'Voreinstellung löschen?';

  @override
  String get mixerDelete => 'Löschen';

  @override
  String get mixerRemoveLayer => 'Ebene entfernen';

  @override
  String get mixerGroupNature => 'Naturklänge';

  @override
  String get mixerGroupMusic => 'Schlaflieder';

  @override
  String get timerTitle => 'Timer';

  @override
  String get timerOff => 'Aus';

  @override
  String get timerEndOfTale => 'Nach dem Märchen';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsBreathing => 'Atmender Kreis';

  @override
  String get settingsBreathingSub =>
      'Die einzige Bewegung auf dem Player-Bildschirm';

  @override
  String get settingsIntro => 'Hintergrund vor dem Märchen (Ritual)';

  @override
  String get settingsTail => 'Nachklang nach dem Märchen (Ritual)';

  @override
  String get settingsTimer => 'Standard-Timer';

  @override
  String get settingsCatalog => 'Katalog';

  @override
  String get settingsCheckUpdates => 'Nach Updates suchen';

  @override
  String get settingsChecking => 'Wird geprüft…';

  @override
  String get settingsUpToDate => 'Der Katalog ist aktuell';

  @override
  String get settingsUpdated => 'Katalog aktualisiert';

  @override
  String get settingsOffline => 'Keine Verbindung – alles funktioniert offline';

  @override
  String get settingsVoice => 'Stimme';

  @override
  String get settingsVocative => 'Anrede des Kindes';

  @override
  String get settingsVocativeSub =>
      'So, wie du dein Kind nennst, z. B. Anni. Wird noch nicht verwendet.';

  @override
  String get settingsVocativeNone => 'Nicht festgelegt';

  @override
  String get settingsPrivacy =>
      'Kein Konto, keine Analyse. Das Internet wird nur genutzt, um den Katalog zu aktualisieren.';

  @override
  String get settingsPrivacyCloning =>
      'Kein Konto, keine Analyse. Das Internet wird nur genutzt, um den Katalog zu aktualisieren, und für deine aufgenommene Stimme.';

  @override
  String get voiceTitle => 'Stimme';

  @override
  String get voiceSystem => 'Stimme des Handys';

  @override
  String get voiceSystemSub => 'Funktioniert sofort und ohne Internet';

  @override
  String get voiceRecord => 'Meine Stimme aufnehmen';

  @override
  String get voiceBeta =>
      'Kostenlose Testversion. Die Stimme braucht ein paar Stunden.';

  @override
  String get voicePending =>
      'Die Stimme wird vorbereitet, bis morgen früh ist sie fertig';

  @override
  String get voiceReady => 'Bereit';

  @override
  String get voiceWaiting =>
      'Die Stimme ist fertig, warte auf die ersten Sätze';

  @override
  String get voiceFailed =>
      'Die Stimme konnte nicht erstellt werden. Versuch die Aufnahme noch einmal.';

  @override
  String get voiceDelete => 'Stimme löschen';

  @override
  String get voiceCancel => 'Abbrechen';

  @override
  String get voiceMissingClips =>
      'Sätze, die noch nicht geladen sind, liest vorerst die Stimme des Handys.';

  @override
  String get voiceHintTitle => 'Das Handy hat keine deutsche Stimme';

  @override
  String get voiceHintIos =>
      'Installiere eine unter Einstellungen → Bedienungshilfen → Gesprochene Inhalte → Stimmen → Deutsch (am besten eine erweiterte oder Premium-Stimme).';

  @override
  String get voiceHintAndroid =>
      'Installiere eine unter Einstellungen → Text-in-Sprache-Ausgabe → Google → Sprachdaten installieren → Deutsch.';

  @override
  String get voiceHintOk => 'Verstanden';

  @override
  String get recTitle => 'Meine Stimme aufnehmen';

  @override
  String get recName => 'Dein Name';

  @override
  String get recNameHint => 'z. B. Jana';

  @override
  String get recTips => 'Bevor du anfängst';

  @override
  String get recRead => 'Lies laut vor';

  @override
  String get recConsent =>
      'Ich bin einverstanden, dass Hajánek aus meiner Aufnahme meine Stimme erstellt. Aufnahme und Stimme liegen nur auf dem Server von Hajánek, und ich kann sie jederzeit löschen.';

  @override
  String get recStart => 'Aufnehmen';

  @override
  String get recStop => 'Fertig';

  @override
  String get recReadHint =>
      'Beim Aufnehmen läuft der Text mit. Wenn er dir davonläuft, tipp auf die Zeile, die du gerade liest.';

  @override
  String get recReadyHint => 'lies weiter, nach 30 s stoppt es von selbst';

  @override
  String get recPlay => 'Anhören';

  @override
  String get recPause => 'Stopp';

  @override
  String get recAgain => 'Neu aufnehmen';

  @override
  String get recUpload => 'Senden';

  @override
  String get recUploading => 'Wird gesendet…';

  @override
  String get recNoMic =>
      'Ohne Zugriff auf das Mikrofon geht es nicht – erlaube ihn in den Einstellungen.';

  @override
  String get recFailed =>
      'Die Aufnahme hat nicht geklappt. Bitte versuch es noch einmal.';

  @override
  String get pairTv => 'Fernseher verbinden';

  @override
  String get pairTvSub =>
      'Dann liest deine Stimme die Märchen auch auf dem Fernseher';

  @override
  String get pairTvHelp =>
      'Öffne auf dem Fernseher Hajánek → Stimme → Mit Handy verbinden. Dort erscheint ein sechsstelliger Code.';

  @override
  String get pairCode => 'Code vom Fernseher';

  @override
  String get pairConfirm => 'Verbinden';

  @override
  String get pairTvDone =>
      'Der Fernseher ist verbunden, die Stimmen werden von selbst geladen.';

  @override
  String get pairBadCode =>
      'Dieser Code passt nicht oder ist abgelaufen. Prüf ihn auf dem Fernseher.';

  @override
  String get tvVoice => 'Stimme';

  @override
  String get tvBackground => 'Hintergrund';

  @override
  String get tvSettings => 'Einstellungen';

  @override
  String get tvOn => 'an';

  @override
  String get tvOff => 'aus';

  @override
  String get tvPause => 'Pause';

  @override
  String get tvResume => 'Weiter';

  @override
  String get tvFavourite => 'Favorit';

  @override
  String get tvUnfavourite => 'Aus Favoriten entfernen';

  @override
  String get tvJukeboxSub => 'Wähl einen Hintergrund, er spielt ohne Märchen';

  @override
  String get tvBalance => 'Stimme ↔ Hintergrund';

  @override
  String get voiceSystemTv => 'Stimme des Fernsehers';

  @override
  String get voiceSystemTvSub =>
      'Ohne Internet, wenn der Fernseher Deutsch spricht';

  @override
  String get voiceParentTvHint =>
      'Die Stimme der Eltern wird auf dem Handy aufgenommen. Verbinde den Fernseher mit dem Handy, dann werden die Stimmen von selbst hierher geladen.';

  @override
  String get voiceHintTitleTv => 'Der Fernseher hat keine deutsche Stimme';

  @override
  String get voiceHintTv =>
      'Die Märchen kann die Stimme der Eltern lesen: nimm sie auf dem Handy auf und verbinde den Fernseher (Stimme → Mit Handy verbinden). Ohne sie spielt nur der Hintergrund.';

  @override
  String get pairTitle => 'Mit Handy verbinden';

  @override
  String get pairSub => 'Die Stimme der Eltern wird auf dem Handy aufgenommen';

  @override
  String get pairInstructions =>
      'Öffne auf dem Handy Hajánek → Stimme → Fernseher verbinden und gib den Code ein';

  @override
  String get pairWaiting => 'Warte auf das Handy…';

  @override
  String get pairDone =>
      'Verbunden. Die Stimmen werden jetzt auf den Fernseher geladen.';

  @override
  String get pairExpired => 'Der Code ist abgelaufen.';

  @override
  String get pairNewCode => 'Neuer Code';

  @override
  String get pairClose => 'Fertig';

  @override
  String minutes(int n) {
    return '$n Min.';
  }

  @override
  String detailAge(String age) {
    return 'Alter $age';
  }

  @override
  String playerIntroLeft(String left) {
    return 'Das Märchen beginnt in $left';
  }

  @override
  String get sectionUvod => 'Ankommen';

  @override
  String get sectionVstup => 'Ins Märchen';

  @override
  String get sectionPribeh => 'Geschichte';

  @override
  String get sectionDojezd => 'Ausklang';

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
    return 'Stimme wird geladen: $done von $total Sätzen';
  }

  @override
  String voiceDeleteConfirm(String name) {
    return 'Stimme „$name“ löschen? Die Aufnahme und alle Sätze werden vom Handy und vom Server gelöscht.';
  }

  @override
  String recMinHint(int s) {
    return 'beenden geht nach $s s';
  }

  @override
  String get balanceVoiceOnly => 'Nur Stimme';

  @override
  String get balanceMoreVoice => 'Mehr Stimme';

  @override
  String get balanceEven => 'Ausgewogen';

  @override
  String get balanceMoreBackground => 'Mehr Hintergrund';

  @override
  String get balanceBackgroundOnly => 'Nur Hintergrund';

  @override
  String get languageTitle => 'Sprache';

  @override
  String get languageSub => 'Sprache der App, der Märchen und der Stimme';

  @override
  String get languageSystem => 'Wie auf dem Handy';

  @override
  String get playerChannel => 'Wiedergabe';

  @override
  String get languageTalesFallback =>
      'Die Märchen gibt es in dieser Sprache noch nicht, sie laufen auf Englisch.';
}
