// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get homeJukebox => 'サウンドジュークボックス';

  @override
  String get homeJukeboxSub => 'お話なしで、BGMだけ';

  @override
  String get homeTales => 'お話';

  @override
  String get homeNowPlaying => '再生中';

  @override
  String get detailVoice => '声';

  @override
  String get detailNoScript => 'お話を読み込めませんでした。';

  @override
  String get detailBackground => 'BGM';

  @override
  String get detailRecommended => 'おすすめ';

  @override
  String get detailNoBackground => 'BGMなし';

  @override
  String get detailRitual => '「おやすみ」の儀式';

  @override
  String get detailRitualSub => '最初はBGMだけ。お話のあとも少しだけ流れ続けます';

  @override
  String get detailPlay => '再生';

  @override
  String get detailFavourite => 'お気に入り';

  @override
  String get playerIntro => 'BGMだけ…';

  @override
  String get playerStartNow => '今すぐ始める';

  @override
  String get playerVoice => 'お話';

  @override
  String get playerTail => 'BGMが静かに続いています';

  @override
  String get playerFadeOut => '静かになっていきます…';

  @override
  String get playerDone => 'おやすみなさい';

  @override
  String get playerMixer => 'ジュークボックス';

  @override
  String get playerBalance => '声 ↔ BGM';

  @override
  String get playerBackground => 'BGM';

  @override
  String get playerStop => '停止';

  @override
  String get playerNothing => '何も再生していません';

  @override
  String get mixerTitle => 'サウンドジュークボックス';

  @override
  String get mixerMain => 'メインの音';

  @override
  String get mixerSecondary => '追加の音';

  @override
  String get mixerAddLayer => 'レイヤーを追加';

  @override
  String get mixerPresets => '保存したミックス';

  @override
  String get mixerSavePreset => 'ミックスを保存';

  @override
  String get mixerPresetName => 'ミックスの名前';

  @override
  String get mixerSave => '保存';

  @override
  String get mixerCancel => 'キャンセル';

  @override
  String get mixerDeletePreset => 'ミックスを削除しますか？';

  @override
  String get mixerDelete => '削除';

  @override
  String get mixerRemoveLayer => 'レイヤーを削除';

  @override
  String get mixerGroupNature => '自然の音';

  @override
  String get mixerGroupMusic => '子守歌';

  @override
  String get timerTitle => 'タイマー';

  @override
  String get timerOff => 'オフ';

  @override
  String get timerEndOfTale => 'お話が終わったら';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsBreathing => '呼吸する円';

  @override
  String get settingsBreathingSub => 'プレーヤー画面で唯一動くもの';

  @override
  String get settingsIntro => 'お話の前のBGM（儀式）';

  @override
  String get settingsTail => 'お話のあとのBGM（儀式）';

  @override
  String get settingsTimer => '標準のタイマー';

  @override
  String get settingsCatalog => 'カタログ';

  @override
  String get settingsCheckUpdates => 'アップデートを確認';

  @override
  String get settingsChecking => '確認中…';

  @override
  String get settingsUpToDate => 'カタログは最新です';

  @override
  String get settingsUpdated => 'カタログを更新しました';

  @override
  String get settingsOffline => 'オフライン — すべてオフラインで使えます';

  @override
  String get settingsVoice => '声';

  @override
  String get settingsVocative => 'お子さまの呼び名';

  @override
  String get settingsVocativeSub => 'お子さまをいつも呼ぶ名前（例：はなちゃん）。まだ使われていません。';

  @override
  String get settingsVocativeNone => '未設定';

  @override
  String get settingsPrivacy => 'アカウントなし、解析なし。ネットワークはカタログの更新にのみ使います。';

  @override
  String get settingsPrivacyCloning =>
      'アカウントなし、解析なし。ネットワークはカタログの更新と、録音したあなたの声にのみ使います。';

  @override
  String get voiceTitle => '声';

  @override
  String get voiceSystem => 'スマホの声';

  @override
  String get voiceSystemSub => 'すぐに使えて、インターネット不要';

  @override
  String get voiceRecord => '自分の声を録音';

  @override
  String get voiceBeta => '無料のお試し版です。声の準備には数時間かかります。';

  @override
  String get voicePending => '声を準備中です。朝までにできあがります';

  @override
  String get voiceReady => '準備完了';

  @override
  String get voiceWaiting => '声ができました。最初の文を待っています';

  @override
  String get voiceFailed => '声を作成できませんでした。もう一度録音してください。';

  @override
  String get voiceDelete => '声を削除';

  @override
  String get voiceCancel => 'キャンセル';

  @override
  String get voiceMissingClips => 'まだダウンロードされていない文は、当面スマホの声が読み上げます。';

  @override
  String get voiceHintTitle => 'スマホに英語の音声がありません';

  @override
  String get voiceHintIos =>
      '設定 → アクセシビリティ → 読み上げコンテンツ → 声 → 英語 からインストールしてください（拡張またはプレミアムの声がおすすめ）。';

  @override
  String get voiceHintAndroid =>
      '設定 → テキスト読み上げの出力 → Google → 音声データのインストール → 英語 からインストールしてください。';

  @override
  String get voiceHintOk => 'わかりました';

  @override
  String get recTitle => '自分の声を録音';

  @override
  String get recName => 'あなたの名前';

  @override
  String get recNameHint => '例：さくら';

  @override
  String get recTips => '始める前に';

  @override
  String get recRead => '声に出して読んでください';

  @override
  String get recConsent =>
      'Hajánekが私の録音から私の声を作成することに同意します。録音と声はHajánekのサーバーにのみ保存され、いつでも削除できます。';

  @override
  String get recStart => '録音';

  @override
  String get recStop => '完了';

  @override
  String get recReadHint =>
      '録音中は、文章があなたに合わせて進みます。先に進みすぎたり遅れたりしたら、今読んでいる行をタップしてください。';

  @override
  String get recReadyHint => 'そのまま読み続けてください。30秒で自動的に止まります';

  @override
  String get recPlay => '聞く';

  @override
  String get recPause => '停止';

  @override
  String get recAgain => '録音し直す';

  @override
  String get recUpload => '送信';

  @override
  String get recUploading => '送信中…';

  @override
  String get recNoMic => 'マイクへのアクセスが必要です。設定で許可してください。';

  @override
  String get recFailed => '録音できませんでした。もう一度お試しください。';

  @override
  String get pairTv => 'テレビとつなぐ';

  @override
  String get pairTvSub => 'あなたの声がテレビでもお話を読みます';

  @override
  String get pairTvHelp => 'テレビでHajánek → 声 → スマホとつなぐ を開くと、6桁のコードが表示されます。';

  @override
  String get pairCode => 'テレビのコード';

  @override
  String get pairConfirm => 'つなぐ';

  @override
  String get pairTvDone => 'テレビとつながりました。声は自動でテレビにダウンロードされます。';

  @override
  String get pairBadCode => 'コードが一致しないか、期限切れです。テレビで確認してください。';

  @override
  String get tvVoice => '声';

  @override
  String get tvBackground => 'BGM';

  @override
  String get tvSettings => '設定';

  @override
  String get tvOn => 'オン';

  @override
  String get tvOff => 'オフ';

  @override
  String get tvPause => '一時停止';

  @override
  String get tvResume => '再開';

  @override
  String get tvFavourite => 'お気に入り';

  @override
  String get tvUnfavourite => 'お気に入りから外す';

  @override
  String get tvJukeboxSub => 'BGMを選ぶと、お話なしで流れます';

  @override
  String get tvBalance => '声 ↔ BGM';

  @override
  String get voiceSystemTv => 'テレビの声';

  @override
  String get voiceSystemTvSub => 'テレビが英語を話せれば、インターネット不要';

  @override
  String get voiceParentTvHint =>
      '保護者の声はスマホで録音します。テレビをスマホとつなぐと、声は自動でここにダウンロードされます。';

  @override
  String get voiceHintTitleTv => 'テレビに英語の音声がありません';

  @override
  String get voiceHintTv =>
      'お話は保護者の声で読むこともできます。スマホで録音して、テレビとつないでください（声 → スマホとつなぐ）。声がない場合はBGMだけが流れます。';

  @override
  String get pairTitle => 'スマホとつなぐ';

  @override
  String get pairSub => '保護者の声はスマホで録音します';

  @override
  String get pairInstructions => 'スマホでHajánek → 声 → テレビとつなぐ を開き、コードを入力してください';

  @override
  String get pairWaiting => 'スマホを待っています…';

  @override
  String get pairDone => 'つながりました。声をテレビにダウンロードしています。';

  @override
  String get pairExpired => 'コードの期限が切れました。';

  @override
  String get pairNewCode => '新しいコード';

  @override
  String get pairClose => '完了';

  @override
  String minutes(int n) {
    return '$n分';
  }

  @override
  String detailAge(String age) {
    return '$age歳';
  }

  @override
  String playerIntroLeft(String left) {
    return 'お話はあと$leftで始まります';
  }

  @override
  String get sectionUvod => '落ち着く';

  @override
  String get sectionVstup => 'お話の入り口';

  @override
  String get sectionPribeh => '物語';

  @override
  String get sectionDojezd => 'おやすみへ';

  @override
  String settingsCatalogVersion(int v) {
    return 'カタログのバージョン $v';
  }

  @override
  String seconds(int n) {
    return '$n秒';
  }

  @override
  String voiceDownloading(int done, int total) {
    return '声をダウンロード中：$total文中$done文';
  }

  @override
  String voiceDeleteConfirm(String name) {
    return '声「$name」を削除しますか？録音とすべての文がスマホとサーバーから削除されます。';
  }

  @override
  String recMinHint(int s) {
    return '$s秒たったら終了できます';
  }

  @override
  String get balanceVoiceOnly => '声だけ';

  @override
  String get balanceMoreVoice => '声を多めに';

  @override
  String get balanceEven => '半々';

  @override
  String get balanceMoreBackground => 'BGMを多めに';

  @override
  String get balanceBackgroundOnly => 'BGMだけ';

  @override
  String get languageTitle => '言語';

  @override
  String get languageSub => 'アプリ、お話、声の言語';

  @override
  String get languageSystem => 'スマホと同じ';

  @override
  String get playerChannel => '再生';

  @override
  String get languageTalesFallback => 'お話はまだこの言語に対応していないため、英語で再生されます。';
}
