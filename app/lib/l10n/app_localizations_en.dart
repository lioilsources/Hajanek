// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get homeJukebox => 'Sound jukebox';

  @override
  String get homeJukeboxSub => 'Just background sounds, no tale';

  @override
  String get homeTales => 'Tales';

  @override
  String get homeNowPlaying => 'Now playing';

  @override
  String get detailVoice => 'Voice';

  @override
  String get detailNoScript => 'The tale couldn\'t be loaded.';

  @override
  String get detailBackground => 'Background';

  @override
  String get detailRecommended => 'Recommended';

  @override
  String get detailNoBackground => 'No background';

  @override
  String get detailRitual => '“Good night” ritual';

  @override
  String get detailRitualSub =>
      'Background first, and it keeps playing a little after the tale';

  @override
  String get detailPlay => 'Play';

  @override
  String get detailFavourite => 'Favourite';

  @override
  String get playerIntro => 'Just background…';

  @override
  String get playerStartNow => 'Start now';

  @override
  String get playerVoice => 'Tale';

  @override
  String get playerTail => 'Background fading';

  @override
  String get playerFadeOut => 'Getting quiet…';

  @override
  String get playerDone => 'Good night';

  @override
  String get playerMixer => 'Jukebox';

  @override
  String get playerBalance => 'Voice ↔ background';

  @override
  String get playerBackground => 'Background';

  @override
  String get playerStop => 'Stop';

  @override
  String get playerNothing => 'Nothing playing';

  @override
  String get mixerTitle => 'Sound jukebox';

  @override
  String get mixerMain => 'Main sound';

  @override
  String get mixerSecondary => 'Extra sound';

  @override
  String get mixerAddLayer => 'Add layer';

  @override
  String get mixerPresets => 'Presets';

  @override
  String get mixerSavePreset => 'Save preset';

  @override
  String get mixerPresetName => 'Preset name';

  @override
  String get mixerSave => 'Save';

  @override
  String get mixerCancel => 'Cancel';

  @override
  String get mixerDeletePreset => 'Delete preset?';

  @override
  String get mixerDelete => 'Delete';

  @override
  String get mixerRemoveLayer => 'Remove layer';

  @override
  String get mixerGroupNature => 'Nature sounds';

  @override
  String get mixerGroupMusic => 'Lullabies';

  @override
  String get timerTitle => 'Timer';

  @override
  String get timerOff => 'Off';

  @override
  String get timerEndOfTale => 'End of tale';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsBreathing => 'Breathing circle';

  @override
  String get settingsBreathingSub => 'The only movement on the player screen';

  @override
  String get settingsIntro => 'Background before the tale (ritual)';

  @override
  String get settingsTail => 'Background after the tale (ritual)';

  @override
  String get settingsTimer => 'Default timer';

  @override
  String get settingsCatalog => 'Catalog';

  @override
  String get settingsCheckUpdates => 'Check for updates';

  @override
  String get settingsChecking => 'Checking…';

  @override
  String get settingsUpToDate => 'The catalog is up to date';

  @override
  String get settingsUpdated => 'Catalog updated';

  @override
  String get settingsOffline => 'No connection — everything works offline';

  @override
  String get settingsVoice => 'Voice';

  @override
  String get settingsVocative => 'What to call your child';

  @override
  String get settingsVocativeSub =>
      'The name you call your child, e.g. Annie. Not used yet.';

  @override
  String get settingsVocativeNone => 'Not set';

  @override
  String get settingsPrivacy =>
      'No account, no analytics. The network is only used to update the catalog.';

  @override
  String get settingsPrivacyCloning =>
      'No account, no analytics. The network is only used to update the catalog and for your recorded voice.';

  @override
  String get voiceTitle => 'Voice';

  @override
  String get voiceSystem => 'Phone voice';

  @override
  String get voiceSystemSub => 'Works right away, no internet needed';

  @override
  String get voiceRecord => 'Record my voice';

  @override
  String get voiceBeta =>
      'Free trial. Your voice takes a few hours to prepare.';

  @override
  String get voicePending =>
      'Your voice is being prepared and will be ready by morning';

  @override
  String get voiceReady => 'Ready';

  @override
  String get voiceWaiting =>
      'Your voice is ready, waiting for the first sentences';

  @override
  String get voiceFailed =>
      'Your voice couldn\'t be created. Try recording again.';

  @override
  String get voiceDelete => 'Delete voice';

  @override
  String get voiceCancel => 'Cancel';

  @override
  String get voiceMissingClips =>
      'Sentences that aren\'t downloaded yet will be read by the phone voice for now.';

  @override
  String get voiceHintTitle => 'Your phone has no English voice';

  @override
  String get voiceHintIos =>
      'Install one in Settings → Accessibility → Spoken Content → Voices → English (ideally an Enhanced or Premium voice).';

  @override
  String get voiceHintAndroid =>
      'Install one in Settings → Text-to-speech output → Google → Install voice data → English.';

  @override
  String get voiceHintOk => 'Got it';

  @override
  String get recTitle => 'Record my voice';

  @override
  String get recName => 'Your name';

  @override
  String get recNameHint => 'e.g. Jane';

  @override
  String get recTips => 'Before you start';

  @override
  String get recRead => 'Read aloud';

  @override
  String get recConsent =>
      'I agree that Hajánek may create my voice from my recording. The recording and the voice are kept only on Hajánek\'s server, and I can delete them at any time.';

  @override
  String get recStart => 'Record';

  @override
  String get recStop => 'Done';

  @override
  String get recReadHint =>
      'While you record, the text moves along with you. If it gets ahead or behind, tap the line you\'re reading.';

  @override
  String get recReadyHint => 'keep reading, it stops by itself after 30 s';

  @override
  String get recPlay => 'Listen';

  @override
  String get recPause => 'Stop';

  @override
  String get recAgain => 'Record again';

  @override
  String get recUpload => 'Send';

  @override
  String get recUploading => 'Sending…';

  @override
  String get recNoMic =>
      'This needs access to the microphone — allow it in Settings.';

  @override
  String get recFailed => 'The recording didn\'t work. Please try again.';

  @override
  String get pairTv => 'Connect a TV';

  @override
  String get pairTvSub => 'Your voice will then read the tales on the TV too';

  @override
  String get pairTvHelp =>
      'On the TV, open Hajánek → Voice → Connect to phone. A six-digit code will appear.';

  @override
  String get pairCode => 'Code from the TV';

  @override
  String get pairConfirm => 'Connect';

  @override
  String get pairTvDone =>
      'The TV is connected. The voices will download to it on their own.';

  @override
  String get pairBadCode =>
      'This code doesn\'t match or has expired. Check it on the TV.';

  @override
  String get tvVoice => 'Voice';

  @override
  String get tvBackground => 'Background';

  @override
  String get tvSettings => 'Settings';

  @override
  String get tvOn => 'on';

  @override
  String get tvOff => 'off';

  @override
  String get tvPause => 'Pause';

  @override
  String get tvResume => 'Resume';

  @override
  String get tvFavourite => 'Favourite';

  @override
  String get tvUnfavourite => 'Remove from favourites';

  @override
  String get tvJukeboxSub => 'Pick a background, it plays without a tale';

  @override
  String get tvBalance => 'Voice ↔ background';

  @override
  String get voiceSystemTv => 'TV voice';

  @override
  String get voiceSystemTvSub => 'Offline, if the TV speaks English';

  @override
  String get voiceParentTvHint =>
      'A parent\'s voice is recorded on the phone. Connect the TV to the phone and the voices will download here on their own.';

  @override
  String get voiceHintTitleTv => 'Your TV has no English voice';

  @override
  String get voiceHintTv =>
      'A parent\'s voice can read the tales: record it on the phone and connect the TV (Voice → Connect to phone). Without it, only the background plays.';

  @override
  String get pairTitle => 'Connect to phone';

  @override
  String get pairSub => 'A parent\'s voice is recorded on the phone';

  @override
  String get pairInstructions =>
      'On the phone, open Hajánek → Voice → Connect a TV and enter the code';

  @override
  String get pairWaiting => 'Waiting for the phone…';

  @override
  String get pairDone => 'Connected. The voices are now downloading to the TV.';

  @override
  String get pairExpired => 'The code has expired.';

  @override
  String get pairNewCode => 'New code';

  @override
  String get pairClose => 'Done';

  @override
  String minutes(int n) {
    return '$n min';
  }

  @override
  String detailAge(String age) {
    return 'age $age';
  }

  @override
  String playerIntroLeft(String left) {
    return 'The tale starts in $left';
  }

  @override
  String get sectionUvod => 'Settling in';

  @override
  String get sectionVstup => 'Into the tale';

  @override
  String get sectionPribeh => 'Story';

  @override
  String get sectionDojezd => 'Winding down';

  @override
  String settingsCatalogVersion(int v) {
    return 'Catalog version $v';
  }

  @override
  String seconds(int n) {
    return '$n s';
  }

  @override
  String voiceDownloading(int done, int total) {
    return 'Downloading voice: $done of $total sentences';
  }

  @override
  String voiceDeleteConfirm(String name) {
    return 'Delete the voice “$name”? The recording and all sentences will be deleted from the phone and from the server.';
  }

  @override
  String recMinHint(int s) {
    return 'you can finish after $s s';
  }

  @override
  String get balanceVoiceOnly => 'Voice only';

  @override
  String get balanceMoreVoice => 'More voice';

  @override
  String get balanceEven => 'Even';

  @override
  String get balanceMoreBackground => 'More background';

  @override
  String get balanceBackgroundOnly => 'Background only';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSub => 'Language of the app, tales and voice';

  @override
  String get languageSystem => 'Same as phone';

  @override
  String get playerChannel => 'Playback';

  @override
  String get languageTalesFallback =>
      'The tales aren’t in this language yet, so they play in English.';
}
