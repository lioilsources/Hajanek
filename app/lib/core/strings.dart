/// All user-facing Czech strings in one place (MVP: no l10n framework yet).
abstract final class S {
  static const appName = 'Hajánek';

  // Home
  static const homeJukebox = 'Jukebox zvuků';
  static const homeJukeboxSub = 'Jen podkres, bez pohádky';
  static const homeTales = 'Pohádky';
  static const homeNowPlaying = 'Právě hraje';
  static String homeMinutes(double seconds) => '${(seconds / 60).round()} min';

  // Tale detail
  static const detailVoice = 'Hlas';
  static const detailNoScript = 'Text pohádky se nepodařilo načíst.';
  static const detailBackground = 'Podkres';
  static const detailRecommended = 'Doporučený';
  static const detailNoBackground = 'Bez podkresu';
  static const detailRitual = 'Rituál „dobrou noc“';
  static const detailRitualSub = 'Nejdřív jen podkres, po pohádce ještě chvíli hraje';
  static const detailPlay = 'Spustit';
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
  static String section(String? id) => switch (id) {
        'uvod' => 'Úvod',
        'vstup' => 'Vstup',
        'pribeh' => 'Příběh',
        'dojezd' => 'Dojezd',
        _ => '',
      };

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
  static const mixerGroupNature = 'Přírodní zvuky';
  static const mixerGroupMusic = 'Ukolébavky';

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
  static const settingsVoice = 'Hlas';
  static const settingsVocative = 'Oslovení dítěte';
  static const settingsVocativeSub = 'V 5. pádě, např. „Aničko“. Zatím se nepoužívá.';
  static const settingsVocativeNone = 'Nenastaveno';
  static const settingsPrivacy =
      'Žádný účet, žádná analytika. Síť se používá jen pro aktualizaci katalogu '
      'a pro tvůj nahraný hlas.';

  // Voice
  static const voiceTitle = 'Hlas';
  static const voiceSystem = 'Hlas telefonu';
  static const voiceSystemSub = 'Funguje hned a bez internetu';
  static const voiceRecord = 'Nahrát můj hlas';
  static const voicePending = 'Hlas se připravuje, bude hotový do rána';
  static String voiceDownloading(int done, int total) => 'Stahuji hlas: $done z $total vět';
  static const voiceReady = 'Připraveno';
  static const voiceWaiting = 'Hlas je hotový, čekám na první věty';
  static const voiceFailed = 'Hlas se nepodařilo vytvořit. Zkus nahrávku zopakovat.';
  static const voiceDelete = 'Smazat hlas';
  static String voiceDeleteConfirm(String name) =>
      'Smazat hlas „$name“? Nahrávka i všechny věty se smažou z telefonu i ze serveru.';
  static const voiceCancel = 'Zrušit';
  static const voiceMissingClips =
      'Věty, které ještě nejsou stažené, přečte zatím hlas telefonu.';
  static const czechHintTitle = 'Telefon nemá český hlas';
  static const czechHintIos =
      'Nainstaluj ho v Nastavení → Zpřístupnění → Předčítání → Hlasy → Čeština '
      '(nejlépe Zuzana ve vylepšené kvalitě).';
  static const czechHintAndroid =
      'Nainstaluj ho v Nastavení → Převod textu na řeč → Google → Nainstalovat hlasová data → čeština.';
  static const czechHintOk = 'Rozumím';

  // Recording
  static const recTitle = 'Nahrát můj hlas';
  static const recName = 'Tvoje jméno';
  static const recNameHint = 'např. Jana';
  static const recTips = 'Než začneš';
  static const recRead = 'Přečti nahlas';
  static const recConsent =
      'Souhlasím, aby Hajánek z mé nahrávky vytvořil můj hlas. Nahrávka i hlas jsou '
      'jen na serveru Hajánka a kdykoli je smažu.';
  static const recStart = 'Nahrávat';
  static const recStop = 'Hotovo';
  static const recReadHint = 'Při nahrávání se text posouvá s tebou. Ťukni na řádek, který právě čteš, když se rozejdete.';
  static String recMinHint(int s) => 'dokončit jde po $s s';
  static const recReadyHint = 'čti dál, po 30 s se zastaví samo';
  static const recPlay = 'Poslechnout';
  static const recPause = 'Zastavit';
  static const recAgain = 'Nahrát znovu';
  static const recUpload = 'Odeslat';
  static const recUploading = 'Odesílám…';
  static const recNoMic = 'Bez přístupu k mikrofonu to nejde — povol ho v Nastavení.';
  static const recFailed = 'Nahrávání se nepodařilo. Zkus to prosím znovu.';
}
