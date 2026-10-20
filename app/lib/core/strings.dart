/// All user-facing Czech strings in one place (MVP: no l10n framework yet).
abstract final class S {
  static const appName = 'Hajánek';

  // Home
  static const homeJukebox = 'Jukebox zvuků';
  static const homeJukeboxSub = 'Jen podkres, bez pohádky';
  static const homeTales = 'Pohádky';
  static const homeNowPlaying = 'Právě hraje';
  static const homeDownloaded = 'staženo';
  static const homeNotDownloaded = 'ke stažení';

  // Tale detail
  static const detailVoice = 'Hlas';
  static const detailBackground = 'Podkres';
  static const detailRecommended = 'Doporučený';
  static const detailNoBackground = 'Bez podkresu';
  static const detailRitual = 'Rituál „dobrou noc“';
  static const detailRitualSub = 'Nejdřív jen podkres, po pohádce ještě chvíli hraje';
  static const detailPlay = 'Spustit';
  static const detailDownload = 'Stáhnout';
  static const detailDownloading = 'Stahuji…';
  static const detailDownloadFailed = 'Stažení se nepovedlo';
  static const detailFavourite = 'Oblíbená';
  static String detailAge(String age) => 'věk $age';

  // Player
  static const playerIntro = 'Jen podkres…';
  static const playerVoice = 'Pohádka';
  static const playerTail = 'Podkres doznívá';
  static const playerFadeOut = 'Utichá…';
  static const playerDone = 'Dobrou noc';
  static const playerMixer = 'Jukebox';
  static const playerBalance = 'Hlas ↔ podkres';
  static const playerBackground = 'Podkres';
  static const playerStop = 'Zastavit';
  static const playerNothing = 'Nic nehraje';

  // Mixer
  static const mixerTitle = 'Jukebox zvuků';
  static const mixerMain = 'Hlavní zvuk';
  static const mixerSecondary = 'Vedlejší zvuk';
  static const mixerAddLayer = 'Přidat vrstvu';
  static const mixerPresets = 'Předvolby';
  static const mixerSavePreset = 'Uložit předvolbu';
  static const mixerPresetName = 'Název předvolby';
  static const mixerSave = 'Uložit';
  static const mixerCancel = 'Zrušit';
  static const mixerDeletePreset = 'Smazat předvolbu?';
  static const mixerDelete = 'Smazat';
  static const mixerRemoveLayer = 'Odebrat vrstvu';

  // Timer
  static const timerTitle = 'Časovač';
  static const timerOff = 'Vypnuto';
  static const timerEndOfTale = 'Po dohrání';
  static String timerMinutes(int m) => '$m min';
  static String timerRemaining(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // Settings
  static const settingsTitle = 'Nastavení';
  static const settingsBreathing = 'Dýchající kruh';
  static const settingsBreathingSub = 'Jediný pohyb na obrazovce přehrávače';
  static const settingsIntro = 'Úvodní podkres (rituál)';
  static const settingsTail = 'Doznívání podkresu (rituál)';
  static const settingsTimer = 'Výchozí časovač';
  static const settingsCatalog = 'Katalog';
  static String settingsCatalogVersion(int v) => 'Verze katalogu $v';
  static const settingsCheckUpdates = 'Zkontrolovat aktualizace';
  static const settingsChecking = 'Kontroluji…';
  static const settingsUpToDate = 'Katalog je aktuální';
  static const settingsUpdated = 'Katalog aktualizován';
  static const settingsOffline = 'Bez připojení — vše funguje offline';
  static String settingsSeconds(int s) => '$s s';
  static String settingsMinutes(int m) => '$m min';
  static const settingsPrivacy =
      'Žádný účet, žádná analytika. Síť se používá jen pro aktualizaci katalogu.';
}
