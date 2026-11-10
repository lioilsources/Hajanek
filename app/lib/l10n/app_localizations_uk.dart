// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get homeJukebox => 'Музичний автомат';

  @override
  String get homeJukeboxSub => 'Лише фонові звуки, без казки';

  @override
  String get homeTales => 'Казки';

  @override
  String get homeNowPlaying => 'Зараз грає';

  @override
  String get detailVoice => 'Голос';

  @override
  String get detailNoScript => 'Не вдалося завантажити казку.';

  @override
  String get detailBackground => 'Фон';

  @override
  String get detailRecommended => 'Рекомендований';

  @override
  String get detailNoBackground => 'Без фону';

  @override
  String get detailRitual => 'Ритуал «на добраніч»';

  @override
  String get detailRitualSub =>
      'Спершу лише фон, а після казки він ще трохи звучить';

  @override
  String get detailPlay => 'Увімкнути';

  @override
  String get detailFavourite => 'Улюблена';

  @override
  String get playerIntro => 'Лише фон…';

  @override
  String get playerStartNow => 'Почати зараз';

  @override
  String get playerVoice => 'Казка';

  @override
  String get playerTail => 'Фон стихає';

  @override
  String get playerFadeOut => 'Стає тихо…';

  @override
  String get playerDone => 'На добраніч';

  @override
  String get playerMixer => 'Автомат звуків';

  @override
  String get playerBalance => 'Голос ↔ фон';

  @override
  String get playerBackground => 'Фон';

  @override
  String get playerStop => 'Зупинити';

  @override
  String get playerNothing => 'Нічого не грає';

  @override
  String get mixerTitle => 'Музичний автомат';

  @override
  String get mixerMain => 'Основний звук';

  @override
  String get mixerSecondary => 'Додатковий звук';

  @override
  String get mixerAddLayer => 'Додати шар';

  @override
  String get mixerPresets => 'Збережені мікси';

  @override
  String get mixerSavePreset => 'Зберегти мікс';

  @override
  String get mixerPresetName => 'Назва міксу';

  @override
  String get mixerSave => 'Зберегти';

  @override
  String get mixerCancel => 'Скасувати';

  @override
  String get mixerDeletePreset => 'Видалити мікс?';

  @override
  String get mixerDelete => 'Видалити';

  @override
  String get mixerRemoveLayer => 'Прибрати шар';

  @override
  String get mixerGroupNature => 'Звуки природи';

  @override
  String get mixerGroupMusic => 'Колискові';

  @override
  String get timerTitle => 'Таймер';

  @override
  String get timerOff => 'Вимк.';

  @override
  String get timerEndOfTale => 'Наприкінці казки';

  @override
  String get settingsTitle => 'Налаштування';

  @override
  String get settingsBreathing => 'Коло, що дихає';

  @override
  String get settingsBreathingSub => 'Єдиний рух на екрані програвача';

  @override
  String get settingsIntro => 'Фон перед казкою (ритуал)';

  @override
  String get settingsTail => 'Фон після казки (ритуал)';

  @override
  String get settingsTimer => 'Таймер за замовчуванням';

  @override
  String get settingsCatalog => 'Каталог';

  @override
  String get settingsCheckUpdates => 'Перевірити оновлення';

  @override
  String get settingsChecking => 'Перевіряю…';

  @override
  String get settingsUpToDate => 'Каталог актуальний';

  @override
  String get settingsUpdated => 'Каталог оновлено';

  @override
  String get settingsOffline => 'Немає з’єднання — усе працює офлайн';

  @override
  String get settingsVoice => 'Голос';

  @override
  String get settingsVocative => 'Як ви звете дитину';

  @override
  String get settingsVocativeSub =>
      'Ім’я, яким ви звете дитину, наприклад Оленко. Поки не використовується.';

  @override
  String get settingsVocativeNone => 'Не задано';

  @override
  String get settingsPrivacy =>
      'Без облікового запису й аналітики. Мережа потрібна лише для оновлення каталогу.';

  @override
  String get settingsPrivacyCloning =>
      'Без облікового запису й аналітики. Мережа потрібна лише для оновлення каталогу та для вашого записаного голосу.';

  @override
  String get voiceTitle => 'Голос';

  @override
  String get voiceSystem => 'Голос телефона';

  @override
  String get voiceSystemSub => 'Працює одразу й без інтернету';

  @override
  String get voiceRecord => 'Записати мій голос';

  @override
  String get voiceBeta =>
      'Безкоштовна пробна версія. Підготовка голосу триває кілька годин.';

  @override
  String get voicePending => 'Ваш голос готується і буде готовий до ранку';

  @override
  String get voiceReady => 'Готово';

  @override
  String get voiceWaiting => 'Голос готовий, чекаємо на перші речення';

  @override
  String get voiceFailed =>
      'Не вдалося створити голос. Спробуйте записати ще раз.';

  @override
  String get voiceDelete => 'Видалити голос';

  @override
  String get voiceCancel => 'Скасувати';

  @override
  String get voiceMissingClips =>
      'Речення, які ще не завантажені, поки що читатиме голос телефона.';

  @override
  String get voiceHintTitle => 'У телефоні немає англійського голосу';

  @override
  String get voiceHintIos =>
      'Установіть його в Параметри → Доступність → Озвучений вміст → Голоси → Англійська (краще покращений або преміум-голос).';

  @override
  String get voiceHintAndroid =>
      'Установіть його в Налаштування → Синтез мовлення → Google → Установити голосові дані → Англійська.';

  @override
  String get voiceHintOk => 'Зрозуміло';

  @override
  String get recTitle => 'Записати мій голос';

  @override
  String get recName => 'Ваше ім’я';

  @override
  String get recNameHint => 'наприклад, Олена';

  @override
  String get recTips => 'Перш ніж почати';

  @override
  String get recRead => 'Прочитайте вголос';

  @override
  String get recConsent =>
      'Я погоджуюся, щоб Hajánek створив мій голос із мого запису. Запис і голос зберігаються лише на сервері Hajánek, і я можу будь-коли їх видалити.';

  @override
  String get recStart => 'Записати';

  @override
  String get recStop => 'Готово';

  @override
  String get recReadHint =>
      'Під час запису текст рухається разом із вами. Якщо він випередив вас або відстав, торкніться рядка, який читаєте.';

  @override
  String get recReadyHint => 'читайте далі, через 30 с запис зупиниться сам';

  @override
  String get recPlay => 'Прослухати';

  @override
  String get recPause => 'Зупинити';

  @override
  String get recAgain => 'Записати знову';

  @override
  String get recUpload => 'Надіслати';

  @override
  String get recUploading => 'Надсилання…';

  @override
  String get recNoMic =>
      'Потрібен доступ до мікрофона — дозвольте його в Налаштуваннях.';

  @override
  String get recFailed => 'Запис не вдався. Спробуйте ще раз.';

  @override
  String get pairTv => 'Під’єднати телевізор';

  @override
  String get pairTvSub => 'Тоді ваш голос читатиме казки й на телевізорі';

  @override
  String get pairTvHelp =>
      'На телевізорі відкрийте Hajánek → Голос → Під’єднати до телефона. З’явиться шестизначний код.';

  @override
  String get pairCode => 'Код із телевізора';

  @override
  String get pairConfirm => 'Під’єднати';

  @override
  String get pairTvDone =>
      'Телевізор під’єднано. Голоси завантажаться на нього самі.';

  @override
  String get pairBadCode =>
      'Код не підходить або застарів. Перевірте його на телевізорі.';

  @override
  String get tvVoice => 'Голос';

  @override
  String get tvBackground => 'Фон';

  @override
  String get tvSettings => 'Налаштування';

  @override
  String get tvOn => 'увімк.';

  @override
  String get tvOff => 'вимк.';

  @override
  String get tvPause => 'Пауза';

  @override
  String get tvResume => 'Продовжити';

  @override
  String get tvFavourite => 'Улюблена';

  @override
  String get tvUnfavourite => 'Прибрати з улюблених';

  @override
  String get tvJukeboxSub => 'Виберіть фон, він грає без казки';

  @override
  String get tvBalance => 'Голос ↔ фон';

  @override
  String get voiceSystemTv => 'Голос телевізора';

  @override
  String get voiceSystemTvSub =>
      'Без інтернету, якщо телевізор говорить англійською';

  @override
  String get voiceParentTvHint =>
      'Голос батьків записується на телефоні. Під’єднайте телевізор до телефона, і голоси завантажаться сюди самі.';

  @override
  String get voiceHintTitleTv => 'У телевізорі немає англійського голосу';

  @override
  String get voiceHintTv =>
      'Казки може читати голос батьків: запишіть його на телефоні й під’єднайте телевізор (Голос → Під’єднати до телефона). Без нього звучить лише фон.';

  @override
  String get pairTitle => 'Під’єднати до телефона';

  @override
  String get pairSub => 'Голос батьків записується на телефоні';

  @override
  String get pairInstructions =>
      'На телефоні відкрийте Hajánek → Голос → Під’єднати телевізор і введіть код';

  @override
  String get pairWaiting => 'Чекаємо на телефон…';

  @override
  String get pairDone => 'Під’єднано. Голоси завантажуються на телевізор.';

  @override
  String get pairExpired => 'Термін дії коду минув.';

  @override
  String get pairNewCode => 'Новий код';

  @override
  String get pairClose => 'Готово';

  @override
  String minutes(int n) {
    return '$n хв';
  }

  @override
  String detailAge(String age) {
    return 'вік $age';
  }

  @override
  String playerIntroLeft(String left) {
    return 'Казка почнеться за $left';
  }

  @override
  String get sectionUvod => 'Влаштовуємось';

  @override
  String get sectionVstup => 'Вхід у казку';

  @override
  String get sectionPribeh => 'Історія';

  @override
  String get sectionDojezd => 'Затихання';

  @override
  String settingsCatalogVersion(int v) {
    return 'Версія каталогу $v';
  }

  @override
  String seconds(int n) {
    return '$n с';
  }

  @override
  String voiceDownloading(int done, int total) {
    return 'Завантаження голосу: $done з $total речень';
  }

  @override
  String voiceDeleteConfirm(String name) {
    return 'Видалити голос «$name»? Запис і всі речення буде видалено з телефона й із сервера.';
  }

  @override
  String recMinHint(int s) {
    return 'завершити можна через $s с';
  }

  @override
  String get balanceVoiceOnly => 'Лише голос';

  @override
  String get balanceMoreVoice => 'Більше голосу';

  @override
  String get balanceEven => 'Порівну';

  @override
  String get balanceMoreBackground => 'Більше фону';

  @override
  String get balanceBackgroundOnly => 'Лише фон';

  @override
  String get languageTitle => 'Мова';

  @override
  String get languageSub => 'Мова застосунку, казок і голосу';

  @override
  String get languageSystem => 'Як у телефоні';

  @override
  String get playerChannel => 'Відтворення';

  @override
  String get languageTalesFallback =>
      'Казок цією мовою поки немає, тож вони звучать англійською.';
}
