// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get homeJukebox => 'Музыкальный автомат';

  @override
  String get homeJukeboxSub => 'Только фоновые звуки, без сказки';

  @override
  String get homeTales => 'Сказки';

  @override
  String get homeNowPlaying => 'Сейчас играет';

  @override
  String get detailVoice => 'Голос';

  @override
  String get detailNoScript => 'Не удалось загрузить сказку.';

  @override
  String get detailBackground => 'Фон';

  @override
  String get detailRecommended => 'Рекомендуемый';

  @override
  String get detailNoBackground => 'Без фона';

  @override
  String get detailRitual => 'Ритуал «спокойной ночи»';

  @override
  String get detailRitualSub =>
      'Сначала только фон, а после сказки он ещё немного звучит';

  @override
  String get detailPlay => 'Включить';

  @override
  String get detailFavourite => 'Избранное';

  @override
  String get playerIntro => 'Только фон…';

  @override
  String get playerStartNow => 'Начать сейчас';

  @override
  String get playerVoice => 'Сказка';

  @override
  String get playerTail => 'Фон затихает';

  @override
  String get playerFadeOut => 'Становится тихо…';

  @override
  String get playerDone => 'Спокойной ночи';

  @override
  String get playerMixer => 'Автомат звуков';

  @override
  String get playerBalance => 'Голос ↔ фон';

  @override
  String get playerBackground => 'Фон';

  @override
  String get playerStop => 'Остановить';

  @override
  String get playerNothing => 'Ничего не играет';

  @override
  String get mixerTitle => 'Музыкальный автомат';

  @override
  String get mixerMain => 'Основной звук';

  @override
  String get mixerSecondary => 'Дополнительный звук';

  @override
  String get mixerAddLayer => 'Добавить слой';

  @override
  String get mixerPresets => 'Сохранённые миксы';

  @override
  String get mixerSavePreset => 'Сохранить микс';

  @override
  String get mixerPresetName => 'Название микса';

  @override
  String get mixerSave => 'Сохранить';

  @override
  String get mixerCancel => 'Отмена';

  @override
  String get mixerDeletePreset => 'Удалить микс?';

  @override
  String get mixerDelete => 'Удалить';

  @override
  String get mixerRemoveLayer => 'Убрать слой';

  @override
  String get mixerGroupNature => 'Звуки природы';

  @override
  String get mixerGroupMusic => 'Колыбельные';

  @override
  String get timerTitle => 'Таймер';

  @override
  String get timerOff => 'Выкл.';

  @override
  String get timerEndOfTale => 'По окончании сказки';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsBreathing => 'Дышащий круг';

  @override
  String get settingsBreathingSub => 'Единственное движение на экране плеера';

  @override
  String get settingsIntro => 'Фон перед сказкой (ритуал)';

  @override
  String get settingsTail => 'Фон после сказки (ритуал)';

  @override
  String get settingsTimer => 'Таймер по умолчанию';

  @override
  String get settingsCatalog => 'Каталог';

  @override
  String get settingsCheckUpdates => 'Проверить обновления';

  @override
  String get settingsChecking => 'Проверяю…';

  @override
  String get settingsUpToDate => 'Каталог актуален';

  @override
  String get settingsUpdated => 'Каталог обновлён';

  @override
  String get settingsOffline => 'Нет подключения — всё работает офлайн';

  @override
  String get settingsVoice => 'Голос';

  @override
  String get settingsVocative => 'Как вы зовёте ребёнка';

  @override
  String get settingsVocativeSub =>
      'Имя, которым вы зовёте ребёнка, например Машенька. Пока не используется.';

  @override
  String get settingsVocativeNone => 'Не задано';

  @override
  String get settingsPrivacy =>
      'Без аккаунта и аналитики. Сеть используется только для обновления каталога.';

  @override
  String get settingsPrivacyCloning =>
      'Без аккаунта и аналитики. Сеть используется только для обновления каталога и для вашего записанного голоса.';

  @override
  String get voiceTitle => 'Голос';

  @override
  String get voiceSystem => 'Голос телефона';

  @override
  String get voiceSystemSub => 'Работает сразу и без интернета';

  @override
  String get voiceRecord => 'Записать мой голос';

  @override
  String get voiceBeta =>
      'Бесплатная пробная версия. Подготовка голоса занимает несколько часов.';

  @override
  String get voicePending => 'Ваш голос готовится и будет готов к утру';

  @override
  String get voiceReady => 'Готово';

  @override
  String get voiceWaiting => 'Голос готов, ждём первые фразы';

  @override
  String get voiceFailed =>
      'Не удалось создать голос. Попробуйте записать ещё раз.';

  @override
  String get voiceDelete => 'Удалить голос';

  @override
  String get voiceCancel => 'Отмена';

  @override
  String get voiceMissingClips =>
      'Фразы, которые ещё не загружены, пока прочитает голос телефона.';

  @override
  String get voiceHintTitle => 'В телефоне нет английского голоса';

  @override
  String get voiceHintIos =>
      'Установите его в Настройки → Универсальный доступ → Устный контент → Голоса → Английский (лучше улучшенный или премиум-голос).';

  @override
  String get voiceHintAndroid =>
      'Установите его в Настройки → Синтез речи → Google → Установить голосовые данные → Английский.';

  @override
  String get voiceHintOk => 'Понятно';

  @override
  String get recTitle => 'Записать мой голос';

  @override
  String get recName => 'Ваше имя';

  @override
  String get recNameHint => 'например, Анна';

  @override
  String get recTips => 'Перед началом';

  @override
  String get recRead => 'Прочитайте вслух';

  @override
  String get recConsent =>
      'Я согласен(-на), чтобы Hajánek создал мой голос по моей записи. Запись и голос хранятся только на сервере Hajánek, и я могу удалить их в любой момент.';

  @override
  String get recStart => 'Записать';

  @override
  String get recStop => 'Готово';

  @override
  String get recReadHint =>
      'Во время записи текст движется вместе с вами. Если он убежал вперёд или отстал, коснитесь строки, которую читаете.';

  @override
  String get recReadyHint =>
      'читайте дальше, через 30 с запись остановится сама';

  @override
  String get recPlay => 'Прослушать';

  @override
  String get recPause => 'Остановить';

  @override
  String get recAgain => 'Записать заново';

  @override
  String get recUpload => 'Отправить';

  @override
  String get recUploading => 'Отправка…';

  @override
  String get recNoMic =>
      'Нужен доступ к микрофону — разрешите его в Настройках.';

  @override
  String get recFailed => 'Запись не удалась. Попробуйте ещё раз.';

  @override
  String get pairTv => 'Подключить телевизор';

  @override
  String get pairTvSub => 'Тогда ваш голос будет читать сказки и на телевизоре';

  @override
  String get pairTvHelp =>
      'На телевизоре откройте Hajánek → Голос → Подключить к телефону. Появится шестизначный код.';

  @override
  String get pairCode => 'Код с телевизора';

  @override
  String get pairConfirm => 'Подключить';

  @override
  String get pairTvDone =>
      'Телевизор подключён. Голоса загрузятся на него сами.';

  @override
  String get pairBadCode =>
      'Код не подходит или устарел. Проверьте его на телевизоре.';

  @override
  String get tvVoice => 'Голос';

  @override
  String get tvBackground => 'Фон';

  @override
  String get tvSettings => 'Настройки';

  @override
  String get tvOn => 'вкл.';

  @override
  String get tvOff => 'выкл.';

  @override
  String get tvPause => 'Пауза';

  @override
  String get tvResume => 'Продолжить';

  @override
  String get tvFavourite => 'Избранное';

  @override
  String get tvUnfavourite => 'Убрать из избранного';

  @override
  String get tvJukeboxSub => 'Выберите фон, он играет без сказки';

  @override
  String get tvBalance => 'Голос ↔ фон';

  @override
  String get voiceSystemTv => 'Голос телевизора';

  @override
  String get voiceSystemTvSub =>
      'Без интернета, если телевизор говорит по-английски';

  @override
  String get voiceParentTvHint =>
      'Голос родителя записывается на телефоне. Подключите телевизор к телефону, и голоса загрузятся сюда сами.';

  @override
  String get voiceHintTitleTv => 'В телевизоре нет английского голоса';

  @override
  String get voiceHintTv =>
      'Сказки может читать голос родителя: запишите его на телефоне и подключите телевизор (Голос → Подключить к телефону). Без него звучит только фон.';

  @override
  String get pairTitle => 'Подключить к телефону';

  @override
  String get pairSub => 'Голос родителя записывается на телефоне';

  @override
  String get pairInstructions =>
      'На телефоне откройте Hajánek → Голос → Подключить телевизор и введите код';

  @override
  String get pairWaiting => 'Ждём телефон…';

  @override
  String get pairDone => 'Подключено. Голоса загружаются на телевизор.';

  @override
  String get pairExpired => 'Срок действия кода истёк.';

  @override
  String get pairNewCode => 'Новый код';

  @override
  String get pairClose => 'Готово';

  @override
  String minutes(int n) {
    return '$n мин';
  }

  @override
  String detailAge(String age) {
    return 'возраст $age';
  }

  @override
  String playerIntroLeft(String left) {
    return 'Сказка начнётся через $left';
  }

  @override
  String get sectionUvod => 'Устраиваемся';

  @override
  String get sectionVstup => 'Вход в сказку';

  @override
  String get sectionPribeh => 'История';

  @override
  String get sectionDojezd => 'Затихание';

  @override
  String settingsCatalogVersion(int v) {
    return 'Версия каталога $v';
  }

  @override
  String seconds(int n) {
    return '$n с';
  }

  @override
  String voiceDownloading(int done, int total) {
    return 'Загрузка голоса: $done из $total фраз';
  }

  @override
  String voiceDeleteConfirm(String name) {
    return 'Удалить голос «$name»? Запись и все фразы будут удалены с телефона и с сервера.';
  }

  @override
  String recMinHint(int s) {
    return 'закончить можно через $s с';
  }

  @override
  String get balanceVoiceOnly => 'Только голос';

  @override
  String get balanceMoreVoice => 'Больше голоса';

  @override
  String get balanceEven => 'Поровну';

  @override
  String get balanceMoreBackground => 'Больше фона';

  @override
  String get balanceBackgroundOnly => 'Только фон';

  @override
  String get languageTitle => 'Язык';

  @override
  String get languageSub => 'Язык приложения, сказок и голоса';

  @override
  String get languageSystem => 'Как в телефоне';

  @override
  String get playerChannel => 'Воспроизведение';

  @override
  String get languageTalesFallback =>
      'Сказок на этом языке пока нет, поэтому они звучат по-английски.';
}
