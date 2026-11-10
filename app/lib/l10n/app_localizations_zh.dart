// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get homeJukebox => '声音点唱机';

  @override
  String get homeJukeboxSub => '只有背景声，没有故事';

  @override
  String get homeTales => '童话';

  @override
  String get homeNowPlaying => '正在播放';

  @override
  String get detailVoice => '声音';

  @override
  String get detailNoScript => '无法加载这个故事。';

  @override
  String get detailBackground => '背景声';

  @override
  String get detailRecommended => '推荐';

  @override
  String get detailNoBackground => '无背景声';

  @override
  String get detailRitual => '“晚安”仪式';

  @override
  String get detailRitualSub => '先只放背景声，故事结束后还会再放一会儿';

  @override
  String get detailPlay => '播放';

  @override
  String get detailFavourite => '收藏';

  @override
  String get playerIntro => '只有背景声…';

  @override
  String get playerStartNow => '现在开始';

  @override
  String get playerVoice => '故事';

  @override
  String get playerTail => '背景声渐弱';

  @override
  String get playerFadeOut => '渐渐安静…';

  @override
  String get playerDone => '晚安';

  @override
  String get playerMixer => '点唱机';

  @override
  String get playerBalance => '人声 ↔ 背景';

  @override
  String get playerBackground => '背景声';

  @override
  String get playerStop => '停止';

  @override
  String get playerNothing => '没有在播放';

  @override
  String get mixerTitle => '声音点唱机';

  @override
  String get mixerMain => '主声音';

  @override
  String get mixerSecondary => '附加声音';

  @override
  String get mixerAddLayer => '添加图层';

  @override
  String get mixerPresets => '已保存的混音';

  @override
  String get mixerSavePreset => '保存混音';

  @override
  String get mixerPresetName => '混音名称';

  @override
  String get mixerSave => '保存';

  @override
  String get mixerCancel => '取消';

  @override
  String get mixerDeletePreset => '删除这个混音？';

  @override
  String get mixerDelete => '删除';

  @override
  String get mixerRemoveLayer => '移除图层';

  @override
  String get mixerGroupNature => '自然之声';

  @override
  String get mixerGroupMusic => '摇篮曲';

  @override
  String get timerTitle => '定时器';

  @override
  String get timerOff => '关闭';

  @override
  String get timerEndOfTale => '故事结束时';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsBreathing => '呼吸圆圈';

  @override
  String get settingsBreathingSub => '播放界面上唯一的动态';

  @override
  String get settingsIntro => '故事前的背景声（仪式）';

  @override
  String get settingsTail => '故事后的背景声（仪式）';

  @override
  String get settingsTimer => '默认定时器';

  @override
  String get settingsCatalog => '目录';

  @override
  String get settingsCheckUpdates => '检查更新';

  @override
  String get settingsChecking => '正在检查…';

  @override
  String get settingsUpToDate => '目录已是最新';

  @override
  String get settingsUpdated => '目录已更新';

  @override
  String get settingsOffline => '没有网络——一切都可离线使用';

  @override
  String get settingsVoice => '声音';

  @override
  String get settingsVocative => '孩子的称呼';

  @override
  String get settingsVocativeSub => '你平时怎么叫孩子，例如：宝贝。暂未使用。';

  @override
  String get settingsVocativeNone => '未设置';

  @override
  String get settingsPrivacy => '无需账户，没有数据分析。网络只用于更新目录。';

  @override
  String get settingsPrivacyCloning => '无需账户，没有数据分析。网络只用于更新目录和你录制的声音。';

  @override
  String get voiceTitle => '声音';

  @override
  String get voiceSystem => '手机语音';

  @override
  String get voiceSystemSub => '立即可用，无需联网';

  @override
  String get voiceRecord => '录制我的声音';

  @override
  String get voiceBeta => '免费试用。准备你的声音需要几个小时。';

  @override
  String get voicePending => '正在准备你的声音，明早之前完成';

  @override
  String get voiceReady => '已就绪';

  @override
  String get voiceWaiting => '你的声音已完成，正在等待第一批句子';

  @override
  String get voiceFailed => '无法生成你的声音。请重新录制。';

  @override
  String get voiceDelete => '删除声音';

  @override
  String get voiceCancel => '取消';

  @override
  String get voiceMissingClips => '尚未下载的句子暂时由手机语音朗读。';

  @override
  String get voiceHintTitle => '手机没有英语语音';

  @override
  String get voiceHintIos => '请在 设置 → 辅助功能 → 朗读内容 → 声音 → 英语 中安装（最好选增强版或高级版语音）。';

  @override
  String get voiceHintAndroid => '请在 设置 → 文字转语音输出 → Google → 安装语音数据 → 英语 中安装。';

  @override
  String get voiceHintOk => '知道了';

  @override
  String get recTitle => '录制我的声音';

  @override
  String get recName => '你的名字';

  @override
  String get recNameHint => '例如：小芳';

  @override
  String get recTips => '开始之前';

  @override
  String get recRead => '请大声朗读';

  @override
  String get recConsent =>
      '我同意 Hajánek 根据我的录音生成我的声音。录音和声音只保存在 Hajánek 的服务器上，我可以随时删除。';

  @override
  String get recStart => '录音';

  @override
  String get recStop => '完成';

  @override
  String get recReadHint => '录音时文字会跟着你移动。如果它跑在前面或落在后面，点一下你正在读的那一行。';

  @override
  String get recReadyHint => '继续读，30 秒后会自动停止';

  @override
  String get recPlay => '试听';

  @override
  String get recPause => '停止';

  @override
  String get recAgain => '重新录制';

  @override
  String get recUpload => '发送';

  @override
  String get recUploading => '正在发送…';

  @override
  String get recNoMic => '需要麦克风权限——请在设置中允许。';

  @override
  String get recFailed => '录音失败。请再试一次。';

  @override
  String get pairTv => '连接电视';

  @override
  String get pairTvSub => '这样你的声音也会在电视上讲故事';

  @override
  String get pairTvHelp => '在电视上打开 Hajánek → 声音 → 连接手机，会显示一个六位数代码。';

  @override
  String get pairCode => '电视上的代码';

  @override
  String get pairConfirm => '连接';

  @override
  String get pairTvDone => '电视已连接。声音会自动下载到电视上。';

  @override
  String get pairBadCode => '代码不匹配或已过期。请在电视上核对。';

  @override
  String get tvVoice => '声音';

  @override
  String get tvBackground => '背景声';

  @override
  String get tvSettings => '设置';

  @override
  String get tvOn => '开';

  @override
  String get tvOff => '关';

  @override
  String get tvPause => '暂停';

  @override
  String get tvResume => '继续';

  @override
  String get tvFavourite => '收藏';

  @override
  String get tvUnfavourite => '取消收藏';

  @override
  String get tvJukeboxSub => '选择背景声，不带故事播放';

  @override
  String get tvBalance => '人声 ↔ 背景';

  @override
  String get voiceSystemTv => '电视语音';

  @override
  String get voiceSystemTvSub => '如果电视支持英语，无需联网';

  @override
  String get voiceParentTvHint => '家长的声音在手机上录制。把电视连接到手机，声音会自动下载到这里。';

  @override
  String get voiceHintTitleTv => '电视没有英语语音';

  @override
  String get voiceHintTv => '故事可以由家长的声音来讲：在手机上录制，再连接电视（声音 → 连接手机）。没有的话只播放背景声。';

  @override
  String get pairTitle => '连接手机';

  @override
  String get pairSub => '家长的声音在手机上录制';

  @override
  String get pairInstructions => '在手机上打开 Hajánek → 声音 → 连接电视，然后输入代码';

  @override
  String get pairWaiting => '正在等待手机…';

  @override
  String get pairDone => '已连接。声音正在下载到电视。';

  @override
  String get pairExpired => '代码已过期。';

  @override
  String get pairNewCode => '新代码';

  @override
  String get pairClose => '完成';

  @override
  String minutes(int n) {
    return '$n 分钟';
  }

  @override
  String detailAge(String age) {
    return '$age 岁';
  }

  @override
  String playerIntroLeft(String left) {
    return '故事将在 $left 后开始';
  }

  @override
  String get sectionUvod => '安顿';

  @override
  String get sectionVstup => '走进故事';

  @override
  String get sectionPribeh => '故事';

  @override
  String get sectionDojezd => '慢慢入睡';

  @override
  String settingsCatalogVersion(int v) {
    return '目录版本 $v';
  }

  @override
  String seconds(int n) {
    return '$n 秒';
  }

  @override
  String voiceDownloading(int done, int total) {
    return '正在下载声音：$done/$total 句';
  }

  @override
  String voiceDeleteConfirm(String name) {
    return '删除声音“$name”？录音和所有句子将从手机和服务器上删除。';
  }

  @override
  String recMinHint(int s) {
    return '$s 秒后可以结束';
  }

  @override
  String get balanceVoiceOnly => '只有人声';

  @override
  String get balanceMoreVoice => '人声多一些';

  @override
  String get balanceEven => '均衡';

  @override
  String get balanceMoreBackground => '背景多一些';

  @override
  String get balanceBackgroundOnly => '只有背景';

  @override
  String get languageTitle => '语言';

  @override
  String get languageSub => '应用、故事和声音的语言';

  @override
  String get languageSystem => '跟随手机';

  @override
  String get playerChannel => '播放';

  @override
  String get languageTalesFallback => '故事暂时还没有这种语言的版本，所以用英语播放。';
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');

  @override
  String get homeJukebox => '声音点唱机';

  @override
  String get homeJukeboxSub => '只有背景声，没有故事';

  @override
  String get homeTales => '童话';

  @override
  String get homeNowPlaying => '正在播放';

  @override
  String get detailVoice => '声音';

  @override
  String get detailNoScript => '无法加载这个故事。';

  @override
  String get detailBackground => '背景声';

  @override
  String get detailRecommended => '推荐';

  @override
  String get detailNoBackground => '无背景声';

  @override
  String get detailRitual => '“晚安”仪式';

  @override
  String get detailRitualSub => '先只放背景声，故事结束后还会再放一会儿';

  @override
  String get detailPlay => '播放';

  @override
  String get detailFavourite => '收藏';

  @override
  String get playerIntro => '只有背景声…';

  @override
  String get playerStartNow => '现在开始';

  @override
  String get playerVoice => '故事';

  @override
  String get playerTail => '背景声渐弱';

  @override
  String get playerFadeOut => '渐渐安静…';

  @override
  String get playerDone => '晚安';

  @override
  String get playerMixer => '点唱机';

  @override
  String get playerBalance => '人声 ↔ 背景';

  @override
  String get playerBackground => '背景声';

  @override
  String get playerStop => '停止';

  @override
  String get playerNothing => '没有在播放';

  @override
  String get mixerTitle => '声音点唱机';

  @override
  String get mixerMain => '主声音';

  @override
  String get mixerSecondary => '附加声音';

  @override
  String get mixerAddLayer => '添加图层';

  @override
  String get mixerPresets => '已保存的混音';

  @override
  String get mixerSavePreset => '保存混音';

  @override
  String get mixerPresetName => '混音名称';

  @override
  String get mixerSave => '保存';

  @override
  String get mixerCancel => '取消';

  @override
  String get mixerDeletePreset => '删除这个混音？';

  @override
  String get mixerDelete => '删除';

  @override
  String get mixerRemoveLayer => '移除图层';

  @override
  String get mixerGroupNature => '自然之声';

  @override
  String get mixerGroupMusic => '摇篮曲';

  @override
  String get timerTitle => '定时器';

  @override
  String get timerOff => '关闭';

  @override
  String get timerEndOfTale => '故事结束时';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsBreathing => '呼吸圆圈';

  @override
  String get settingsBreathingSub => '播放界面上唯一的动态';

  @override
  String get settingsIntro => '故事前的背景声（仪式）';

  @override
  String get settingsTail => '故事后的背景声（仪式）';

  @override
  String get settingsTimer => '默认定时器';

  @override
  String get settingsCatalog => '目录';

  @override
  String get settingsCheckUpdates => '检查更新';

  @override
  String get settingsChecking => '正在检查…';

  @override
  String get settingsUpToDate => '目录已是最新';

  @override
  String get settingsUpdated => '目录已更新';

  @override
  String get settingsOffline => '没有网络——一切都可离线使用';

  @override
  String get settingsVoice => '声音';

  @override
  String get settingsVocative => '孩子的称呼';

  @override
  String get settingsVocativeSub => '你平时怎么叫孩子，例如：宝贝。暂未使用。';

  @override
  String get settingsVocativeNone => '未设置';

  @override
  String get settingsPrivacy => '无需账户，没有数据分析。网络只用于更新目录。';

  @override
  String get settingsPrivacyCloning => '无需账户，没有数据分析。网络只用于更新目录和你录制的声音。';

  @override
  String get voiceTitle => '声音';

  @override
  String get voiceSystem => '手机语音';

  @override
  String get voiceSystemSub => '立即可用，无需联网';

  @override
  String get voiceRecord => '录制我的声音';

  @override
  String get voiceBeta => '免费试用。准备你的声音需要几个小时。';

  @override
  String get voicePending => '正在准备你的声音，明早之前完成';

  @override
  String get voiceReady => '已就绪';

  @override
  String get voiceWaiting => '你的声音已完成，正在等待第一批句子';

  @override
  String get voiceFailed => '无法生成你的声音。请重新录制。';

  @override
  String get voiceDelete => '删除声音';

  @override
  String get voiceCancel => '取消';

  @override
  String get voiceMissingClips => '尚未下载的句子暂时由手机语音朗读。';

  @override
  String get voiceHintTitle => '手机没有英语语音';

  @override
  String get voiceHintIos => '请在 设置 → 辅助功能 → 朗读内容 → 声音 → 英语 中安装（最好选增强版或高级版语音）。';

  @override
  String get voiceHintAndroid => '请在 设置 → 文字转语音输出 → Google → 安装语音数据 → 英语 中安装。';

  @override
  String get voiceHintOk => '知道了';

  @override
  String get recTitle => '录制我的声音';

  @override
  String get recName => '你的名字';

  @override
  String get recNameHint => '例如：小芳';

  @override
  String get recTips => '开始之前';

  @override
  String get recRead => '请大声朗读';

  @override
  String get recConsent =>
      '我同意 Hajánek 根据我的录音生成我的声音。录音和声音只保存在 Hajánek 的服务器上，我可以随时删除。';

  @override
  String get recStart => '录音';

  @override
  String get recStop => '完成';

  @override
  String get recReadHint => '录音时文字会跟着你移动。如果它跑在前面或落在后面，点一下你正在读的那一行。';

  @override
  String get recReadyHint => '继续读，30 秒后会自动停止';

  @override
  String get recPlay => '试听';

  @override
  String get recPause => '停止';

  @override
  String get recAgain => '重新录制';

  @override
  String get recUpload => '发送';

  @override
  String get recUploading => '正在发送…';

  @override
  String get recNoMic => '需要麦克风权限——请在设置中允许。';

  @override
  String get recFailed => '录音失败。请再试一次。';

  @override
  String get pairTv => '连接电视';

  @override
  String get pairTvSub => '这样你的声音也会在电视上讲故事';

  @override
  String get pairTvHelp => '在电视上打开 Hajánek → 声音 → 连接手机，会显示一个六位数代码。';

  @override
  String get pairCode => '电视上的代码';

  @override
  String get pairConfirm => '连接';

  @override
  String get pairTvDone => '电视已连接。声音会自动下载到电视上。';

  @override
  String get pairBadCode => '代码不匹配或已过期。请在电视上核对。';

  @override
  String get tvVoice => '声音';

  @override
  String get tvBackground => '背景声';

  @override
  String get tvSettings => '设置';

  @override
  String get tvOn => '开';

  @override
  String get tvOff => '关';

  @override
  String get tvPause => '暂停';

  @override
  String get tvResume => '继续';

  @override
  String get tvFavourite => '收藏';

  @override
  String get tvUnfavourite => '取消收藏';

  @override
  String get tvJukeboxSub => '选择背景声，不带故事播放';

  @override
  String get tvBalance => '人声 ↔ 背景';

  @override
  String get voiceSystemTv => '电视语音';

  @override
  String get voiceSystemTvSub => '如果电视支持英语，无需联网';

  @override
  String get voiceParentTvHint => '家长的声音在手机上录制。把电视连接到手机，声音会自动下载到这里。';

  @override
  String get voiceHintTitleTv => '电视没有英语语音';

  @override
  String get voiceHintTv => '故事可以由家长的声音来讲：在手机上录制，再连接电视（声音 → 连接手机）。没有的话只播放背景声。';

  @override
  String get pairTitle => '连接手机';

  @override
  String get pairSub => '家长的声音在手机上录制';

  @override
  String get pairInstructions => '在手机上打开 Hajánek → 声音 → 连接电视，然后输入代码';

  @override
  String get pairWaiting => '正在等待手机…';

  @override
  String get pairDone => '已连接。声音正在下载到电视。';

  @override
  String get pairExpired => '代码已过期。';

  @override
  String get pairNewCode => '新代码';

  @override
  String get pairClose => '完成';

  @override
  String minutes(int n) {
    return '$n 分钟';
  }

  @override
  String detailAge(String age) {
    return '$age 岁';
  }

  @override
  String playerIntroLeft(String left) {
    return '故事将在 $left 后开始';
  }

  @override
  String get sectionUvod => '安顿';

  @override
  String get sectionVstup => '走进故事';

  @override
  String get sectionPribeh => '故事';

  @override
  String get sectionDojezd => '慢慢入睡';

  @override
  String settingsCatalogVersion(int v) {
    return '目录版本 $v';
  }

  @override
  String seconds(int n) {
    return '$n 秒';
  }

  @override
  String voiceDownloading(int done, int total) {
    return '正在下载声音：$done/$total 句';
  }

  @override
  String voiceDeleteConfirm(String name) {
    return '删除声音“$name”？录音和所有句子将从手机和服务器上删除。';
  }

  @override
  String recMinHint(int s) {
    return '$s 秒后可以结束';
  }

  @override
  String get balanceVoiceOnly => '只有人声';

  @override
  String get balanceMoreVoice => '人声多一些';

  @override
  String get balanceEven => '均衡';

  @override
  String get balanceMoreBackground => '背景多一些';

  @override
  String get balanceBackgroundOnly => '只有背景';

  @override
  String get languageTitle => '语言';

  @override
  String get languageSub => '应用、故事和声音的语言';

  @override
  String get languageSystem => '跟随手机';

  @override
  String get playerChannel => '播放';

  @override
  String get languageTalesFallback => '故事暂时还没有这种语言的版本，所以用英语播放。';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get homeJukebox => '聲音點唱機';

  @override
  String get homeJukeboxSub => '只有背景聲，沒有故事';

  @override
  String get homeTales => '童話';

  @override
  String get homeNowPlaying => '正在播放';

  @override
  String get detailVoice => '聲音';

  @override
  String get detailNoScript => '無法載入這個故事。';

  @override
  String get detailBackground => '背景聲';

  @override
  String get detailRecommended => '推薦';

  @override
  String get detailNoBackground => '無背景聲';

  @override
  String get detailRitual => '「晚安」儀式';

  @override
  String get detailRitualSub => '先只播背景聲，故事結束後還會再播一會兒';

  @override
  String get detailPlay => '播放';

  @override
  String get detailFavourite => '收藏';

  @override
  String get playerIntro => '只有背景聲…';

  @override
  String get playerStartNow => '現在開始';

  @override
  String get playerVoice => '故事';

  @override
  String get playerTail => '背景聲漸弱';

  @override
  String get playerFadeOut => '漸漸安靜…';

  @override
  String get playerDone => '晚安';

  @override
  String get playerMixer => '點唱機';

  @override
  String get playerBalance => '人聲 ↔ 背景';

  @override
  String get playerBackground => '背景聲';

  @override
  String get playerStop => '停止';

  @override
  String get playerNothing => '沒有在播放';

  @override
  String get mixerTitle => '聲音點唱機';

  @override
  String get mixerMain => '主聲音';

  @override
  String get mixerSecondary => '附加聲音';

  @override
  String get mixerAddLayer => '新增圖層';

  @override
  String get mixerPresets => '已儲存的混音';

  @override
  String get mixerSavePreset => '儲存混音';

  @override
  String get mixerPresetName => '混音名稱';

  @override
  String get mixerSave => '儲存';

  @override
  String get mixerCancel => '取消';

  @override
  String get mixerDeletePreset => '刪除這個混音？';

  @override
  String get mixerDelete => '刪除';

  @override
  String get mixerRemoveLayer => '移除圖層';

  @override
  String get mixerGroupNature => '自然之聲';

  @override
  String get mixerGroupMusic => '搖籃曲';

  @override
  String get timerTitle => '計時器';

  @override
  String get timerOff => '關閉';

  @override
  String get timerEndOfTale => '故事結束時';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsBreathing => '呼吸圓圈';

  @override
  String get settingsBreathingSub => '播放畫面上唯一的動態';

  @override
  String get settingsIntro => '故事前的背景聲（儀式）';

  @override
  String get settingsTail => '故事後的背景聲（儀式）';

  @override
  String get settingsTimer => '預設計時器';

  @override
  String get settingsCatalog => '目錄';

  @override
  String get settingsCheckUpdates => '檢查更新';

  @override
  String get settingsChecking => '正在檢查…';

  @override
  String get settingsUpToDate => '目錄已是最新';

  @override
  String get settingsUpdated => '目錄已更新';

  @override
  String get settingsOffline => '沒有網路——一切都可離線使用';

  @override
  String get settingsVoice => '聲音';

  @override
  String get settingsVocative => '孩子的稱呼';

  @override
  String get settingsVocativeSub => '你平常怎麼叫孩子，例如：寶貝。暫未使用。';

  @override
  String get settingsVocativeNone => '未設定';

  @override
  String get settingsPrivacy => '不需帳號，沒有數據分析。網路只用於更新目錄。';

  @override
  String get settingsPrivacyCloning => '不需帳號，沒有數據分析。網路只用於更新目錄和你錄製的聲音。';

  @override
  String get voiceTitle => '聲音';

  @override
  String get voiceSystem => '手機語音';

  @override
  String get voiceSystemSub => '立即可用，不需連網';

  @override
  String get voiceRecord => '錄製我的聲音';

  @override
  String get voiceBeta => '免費試用。準備你的聲音需要幾個小時。';

  @override
  String get voicePending => '正在準備你的聲音，明早之前完成';

  @override
  String get voiceReady => '已就緒';

  @override
  String get voiceWaiting => '你的聲音已完成，正在等待第一批句子';

  @override
  String get voiceFailed => '無法產生你的聲音。請重新錄製。';

  @override
  String get voiceDelete => '刪除聲音';

  @override
  String get voiceCancel => '取消';

  @override
  String get voiceMissingClips => '尚未下載的句子暫時由手機語音朗讀。';

  @override
  String get voiceHintTitle => '手機沒有英語語音';

  @override
  String get voiceHintIos => '請在 設定 → 輔助使用 → 朗讀內容 → 聲音 → 英文 中安裝（最好選加強版或高品質語音）。';

  @override
  String get voiceHintAndroid => '請在 設定 → 文字轉語音輸出 → Google → 安裝語音資料 → 英文 中安裝。';

  @override
  String get voiceHintOk => '知道了';

  @override
  String get recTitle => '錄製我的聲音';

  @override
  String get recName => '你的名字';

  @override
  String get recNameHint => '例如：小美';

  @override
  String get recTips => '開始之前';

  @override
  String get recRead => '請大聲朗讀';

  @override
  String get recConsent =>
      '我同意 Hajánek 根據我的錄音產生我的聲音。錄音和聲音只儲存在 Hajánek 的伺服器上，我可以隨時刪除。';

  @override
  String get recStart => '錄音';

  @override
  String get recStop => '完成';

  @override
  String get recReadHint => '錄音時文字會跟著你移動。如果它跑在前面或落在後面，點一下你正在讀的那一行。';

  @override
  String get recReadyHint => '繼續讀，30 秒後會自動停止';

  @override
  String get recPlay => '試聽';

  @override
  String get recPause => '停止';

  @override
  String get recAgain => '重新錄製';

  @override
  String get recUpload => '傳送';

  @override
  String get recUploading => '正在傳送…';

  @override
  String get recNoMic => '需要麥克風權限——請在設定中允許。';

  @override
  String get recFailed => '錄音失敗。請再試一次。';

  @override
  String get pairTv => '連接電視';

  @override
  String get pairTvSub => '這樣你的聲音也會在電視上講故事';

  @override
  String get pairTvHelp => '在電視上開啟 Hajánek → 聲音 → 連接手機，會顯示一組六位數代碼。';

  @override
  String get pairCode => '電視上的代碼';

  @override
  String get pairConfirm => '連接';

  @override
  String get pairTvDone => '電視已連接。聲音會自動下載到電視上。';

  @override
  String get pairBadCode => '代碼不符或已過期。請在電視上核對。';

  @override
  String get tvVoice => '聲音';

  @override
  String get tvBackground => '背景聲';

  @override
  String get tvSettings => '設定';

  @override
  String get tvOn => '開';

  @override
  String get tvOff => '關';

  @override
  String get tvPause => '暫停';

  @override
  String get tvResume => '繼續';

  @override
  String get tvFavourite => '收藏';

  @override
  String get tvUnfavourite => '取消收藏';

  @override
  String get tvJukeboxSub => '選擇背景聲，不帶故事播放';

  @override
  String get tvBalance => '人聲 ↔ 背景';

  @override
  String get voiceSystemTv => '電視語音';

  @override
  String get voiceSystemTvSub => '如果電視支援英文，不需連網';

  @override
  String get voiceParentTvHint => '家長的聲音在手機上錄製。把電視連接到手機，聲音會自動下載到這裡。';

  @override
  String get voiceHintTitleTv => '電視沒有英語語音';

  @override
  String get voiceHintTv => '故事可以由家長的聲音來講：在手機上錄製，再連接電視（聲音 → 連接手機）。沒有的話只播放背景聲。';

  @override
  String get pairTitle => '連接手機';

  @override
  String get pairSub => '家長的聲音在手機上錄製';

  @override
  String get pairInstructions => '在手機上開啟 Hajánek → 聲音 → 連接電視，然後輸入代碼';

  @override
  String get pairWaiting => '正在等待手機…';

  @override
  String get pairDone => '已連接。聲音正在下載到電視。';

  @override
  String get pairExpired => '代碼已過期。';

  @override
  String get pairNewCode => '新代碼';

  @override
  String get pairClose => '完成';

  @override
  String minutes(int n) {
    return '$n 分鐘';
  }

  @override
  String detailAge(String age) {
    return '$age 歲';
  }

  @override
  String playerIntroLeft(String left) {
    return '故事將在 $left 後開始';
  }

  @override
  String get sectionUvod => '安頓';

  @override
  String get sectionVstup => '走進故事';

  @override
  String get sectionPribeh => '故事';

  @override
  String get sectionDojezd => '慢慢入睡';

  @override
  String settingsCatalogVersion(int v) {
    return '目錄版本 $v';
  }

  @override
  String seconds(int n) {
    return '$n 秒';
  }

  @override
  String voiceDownloading(int done, int total) {
    return '正在下載聲音：$done/$total 句';
  }

  @override
  String voiceDeleteConfirm(String name) {
    return '刪除聲音「$name」？錄音和所有句子將從手機和伺服器上刪除。';
  }

  @override
  String recMinHint(int s) {
    return '$s 秒後可以結束';
  }

  @override
  String get balanceVoiceOnly => '只有人聲';

  @override
  String get balanceMoreVoice => '人聲多一些';

  @override
  String get balanceEven => '均衡';

  @override
  String get balanceMoreBackground => '背景多一些';

  @override
  String get balanceBackgroundOnly => '只有背景';

  @override
  String get languageTitle => '語言';

  @override
  String get languageSub => 'App、故事和聲音的語言';

  @override
  String get languageSystem => '跟隨手機';

  @override
  String get playerChannel => '播放';

  @override
  String get languageTalesFallback => '故事暫時還沒有這種語言的版本，所以用英文播放。';
}
