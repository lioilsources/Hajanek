// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get homeJukebox => 'Jukebox de sons';

  @override
  String get homeJukeboxSub => 'Juste un fond sonore, sans conte';

  @override
  String get homeTales => 'Contes';

  @override
  String get homeNowPlaying => 'En cours';

  @override
  String get detailVoice => 'Voix';

  @override
  String get detailNoScript => 'Impossible de charger le conte.';

  @override
  String get detailBackground => 'Fond sonore';

  @override
  String get detailRecommended => 'Recommandé';

  @override
  String get detailNoBackground => 'Sans fond sonore';

  @override
  String get detailRitual => 'Rituel « bonne nuit »';

  @override
  String get detailRitualSub =>
      'D’abord le fond sonore seul, qui continue encore un peu après le conte';

  @override
  String get detailPlay => 'Lancer';

  @override
  String get detailFavourite => 'Favori';

  @override
  String get playerIntro => 'Fond sonore seul…';

  @override
  String get playerStartNow => 'Commencer tout de suite';

  @override
  String get playerVoice => 'Conte';

  @override
  String get playerTail => 'Le fond sonore s’éteint';

  @override
  String get playerFadeOut => 'Tout s’apaise…';

  @override
  String get playerDone => 'Bonne nuit';

  @override
  String get playerMixer => 'Jukebox';

  @override
  String get playerBalance => 'Voix ↔ fond sonore';

  @override
  String get playerBackground => 'Fond sonore';

  @override
  String get playerStop => 'Arrêter';

  @override
  String get playerNothing => 'Rien en cours';

  @override
  String get mixerTitle => 'Jukebox de sons';

  @override
  String get mixerMain => 'Son principal';

  @override
  String get mixerSecondary => 'Son secondaire';

  @override
  String get mixerAddLayer => 'Ajouter une couche';

  @override
  String get mixerPresets => 'Mélanges';

  @override
  String get mixerSavePreset => 'Enregistrer le mélange';

  @override
  String get mixerPresetName => 'Nom du mélange';

  @override
  String get mixerSave => 'Enregistrer';

  @override
  String get mixerCancel => 'Annuler';

  @override
  String get mixerDeletePreset => 'Supprimer le mélange ?';

  @override
  String get mixerDelete => 'Supprimer';

  @override
  String get mixerRemoveLayer => 'Retirer la couche';

  @override
  String get mixerGroupNature => 'Sons de la nature';

  @override
  String get mixerGroupMusic => 'Berceuses';

  @override
  String get timerTitle => 'Minuteur';

  @override
  String get timerOff => 'Désactivé';

  @override
  String get timerEndOfTale => 'À la fin du conte';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsBreathing => 'Cercle qui respire';

  @override
  String get settingsBreathingSub => 'Le seul mouvement sur l’écran de lecture';

  @override
  String get settingsIntro => 'Fond sonore avant le conte (rituel)';

  @override
  String get settingsTail => 'Fond sonore après le conte (rituel)';

  @override
  String get settingsTimer => 'Minuteur par défaut';

  @override
  String get settingsCatalog => 'Catalogue';

  @override
  String get settingsCheckUpdates => 'Rechercher des mises à jour';

  @override
  String get settingsChecking => 'Vérification…';

  @override
  String get settingsUpToDate => 'Le catalogue est à jour';

  @override
  String get settingsUpdated => 'Catalogue mis à jour';

  @override
  String get settingsOffline => 'Pas de connexion : tout fonctionne hors ligne';

  @override
  String get settingsVoice => 'Voix';

  @override
  String get settingsVocative => 'Comment appeler votre enfant';

  @override
  String get settingsVocativeSub =>
      'Le prénom que vous donnez à votre enfant, par ex. Annie. Pas encore utilisé.';

  @override
  String get settingsVocativeNone => 'Non défini';

  @override
  String get settingsPrivacy =>
      'Pas de compte, pas de statistiques. Le réseau sert uniquement à mettre à jour le catalogue.';

  @override
  String get settingsPrivacyCloning =>
      'Pas de compte, pas de statistiques. Le réseau sert uniquement à mettre à jour le catalogue et à votre voix enregistrée.';

  @override
  String get voiceTitle => 'Voix';

  @override
  String get voiceSystem => 'Voix du téléphone';

  @override
  String get voiceSystemSub => 'Fonctionne tout de suite, sans internet';

  @override
  String get voiceRecord => 'Enregistrer ma voix';

  @override
  String get voiceBeta =>
      'Version d’essai gratuite. La voix met quelques heures à être prête.';

  @override
  String get voicePending =>
      'Votre voix est en préparation, elle sera prête demain matin';

  @override
  String get voiceReady => 'Prête';

  @override
  String get voiceWaiting =>
      'La voix est prête, en attente des premières phrases';

  @override
  String get voiceFailed =>
      'Impossible de créer la voix. Essayez de refaire l’enregistrement.';

  @override
  String get voiceDelete => 'Supprimer la voix';

  @override
  String get voiceCancel => 'Annuler';

  @override
  String get voiceMissingClips =>
      'Les phrases pas encore téléchargées seront lues pour l’instant par la voix du téléphone.';

  @override
  String get voiceHintTitle => 'Le téléphone n’a pas de voix française';

  @override
  String get voiceHintIos =>
      'Installez-en une dans Réglages → Accessibilité → Contenu énoncé → Voix → Français (de préférence une voix améliorée ou premium).';

  @override
  String get voiceHintAndroid =>
      'Installez-en une dans Paramètres → Synthèse vocale → Google → Installer les données vocales → Français.';

  @override
  String get voiceHintOk => 'Compris';

  @override
  String get recTitle => 'Enregistrer ma voix';

  @override
  String get recName => 'Votre prénom';

  @override
  String get recNameHint => 'par ex. Jeanne';

  @override
  String get recTips => 'Avant de commencer';

  @override
  String get recRead => 'Lisez à voix haute';

  @override
  String get recConsent =>
      'J’accepte que Hajánek crée ma voix à partir de mon enregistrement. L’enregistrement et la voix restent uniquement sur le serveur de Hajánek et je peux les supprimer à tout moment.';

  @override
  String get recStart => 'Enregistrer';

  @override
  String get recStop => 'Terminé';

  @override
  String get recReadHint =>
      'Pendant l’enregistrement, le texte avance avec vous. S’il prend de l’avance ou du retard, touchez la ligne que vous lisez.';

  @override
  String get recReadyHint =>
      'continuez à lire, l’enregistrement s’arrête seul après 30 s';

  @override
  String get recPlay => 'Écouter';

  @override
  String get recPause => 'Arrêter';

  @override
  String get recAgain => 'Recommencer';

  @override
  String get recUpload => 'Envoyer';

  @override
  String get recUploading => 'Envoi…';

  @override
  String get recNoMic =>
      'Impossible sans accès au micro : autorisez-le dans les Réglages.';

  @override
  String get recFailed => 'L’enregistrement a échoué. Veuillez réessayer.';

  @override
  String get pairTv => 'Connecter la télé';

  @override
  String get pairTvSub => 'Votre voix lira alors les contes aussi à la télé';

  @override
  String get pairTvHelp =>
      'Sur la télé, ouvrez Hajánek → Voix → Connecter au téléphone. Un code à six chiffres s’affiche.';

  @override
  String get pairCode => 'Code affiché sur la télé';

  @override
  String get pairConfirm => 'Connecter';

  @override
  String get pairTvDone =>
      'La télé est connectée, les voix s’y téléchargeront toutes seules.';

  @override
  String get pairBadCode =>
      'Ce code ne correspond pas ou a expiré. Vérifiez-le sur la télé.';

  @override
  String get tvVoice => 'Voix';

  @override
  String get tvBackground => 'Fond sonore';

  @override
  String get tvSettings => 'Réglages';

  @override
  String get tvOn => 'activé';

  @override
  String get tvOff => 'désactivé';

  @override
  String get tvPause => 'Pause';

  @override
  String get tvResume => 'Reprendre';

  @override
  String get tvFavourite => 'Favori';

  @override
  String get tvUnfavourite => 'Retirer des favoris';

  @override
  String get tvJukeboxSub => 'Choisissez un fond sonore, il joue sans conte';

  @override
  String get tvBalance => 'Voix ↔ fond sonore';

  @override
  String get voiceSystemTv => 'Voix de la télé';

  @override
  String get voiceSystemTvSub => 'Sans internet, si la télé parle français';

  @override
  String get voiceParentTvHint =>
      'La voix d’un parent s’enregistre sur le téléphone. Connectez la télé au téléphone et les voix s’y téléchargeront toutes seules.';

  @override
  String get voiceHintTitleTv => 'La télé n’a pas de voix française';

  @override
  String get voiceHintTv =>
      'La voix d’un parent peut lire les contes : enregistrez-la sur le téléphone et connectez la télé (Voix → Connecter au téléphone). Sans elle, seul le fond sonore joue.';

  @override
  String get pairTitle => 'Connecter au téléphone';

  @override
  String get pairSub => 'La voix d’un parent s’enregistre sur le téléphone';

  @override
  String get pairInstructions =>
      'Sur le téléphone, ouvrez Hajánek → Voix → Connecter la télé et saisissez le code';

  @override
  String get pairWaiting => 'En attente du téléphone…';

  @override
  String get pairDone =>
      'Connecté. Les voix se téléchargent maintenant sur la télé.';

  @override
  String get pairExpired => 'Le code a expiré.';

  @override
  String get pairNewCode => 'Nouveau code';

  @override
  String get pairClose => 'Terminé';

  @override
  String minutes(int n) {
    return '$n min';
  }

  @override
  String detailAge(String age) {
    return 'âge $age';
  }

  @override
  String playerIntroLeft(String left) {
    return 'Le conte commence dans $left';
  }

  @override
  String get sectionUvod => 'Installation';

  @override
  String get sectionVstup => 'Entrée dans le conte';

  @override
  String get sectionPribeh => 'Histoire';

  @override
  String get sectionDojezd => 'Endormissement';

  @override
  String settingsCatalogVersion(int v) {
    return 'Version du catalogue $v';
  }

  @override
  String seconds(int n) {
    return '$n s';
  }

  @override
  String voiceDownloading(int done, int total) {
    return 'Téléchargement de la voix : $done phrases sur $total';
  }

  @override
  String voiceDeleteConfirm(String name) {
    return 'Supprimer la voix « $name » ? L’enregistrement et toutes les phrases seront supprimés du téléphone et du serveur.';
  }

  @override
  String recMinHint(int s) {
    return 'vous pourrez terminer après $s s';
  }

  @override
  String get balanceVoiceOnly => 'Voix seule';

  @override
  String get balanceMoreVoice => 'Plus de voix';

  @override
  String get balanceEven => 'Équilibré';

  @override
  String get balanceMoreBackground => 'Plus de fond sonore';

  @override
  String get balanceBackgroundOnly => 'Fond sonore seul';

  @override
  String get languageTitle => 'Langue';

  @override
  String get languageSub => 'Langue de l’app, des contes et de la voix';

  @override
  String get languageSystem => 'Comme le téléphone';

  @override
  String get playerChannel => 'Lecture';

  @override
  String get languageTalesFallback =>
      'Les contes ne sont pas encore dans cette langue, ils sont lus en anglais.';
}
