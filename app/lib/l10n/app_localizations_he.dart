// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get homeJukebox => 'תיבת צלילים';

  @override
  String get homeJukeboxSub => 'רק צלילי רקע, בלי אגדה';

  @override
  String get homeTales => 'אגדות';

  @override
  String get homeNowPlaying => 'מתנגן עכשיו';

  @override
  String get detailVoice => 'קול';

  @override
  String get detailNoScript => 'לא ניתן לטעון את האגדה.';

  @override
  String get detailBackground => 'רקע';

  @override
  String get detailRecommended => 'מומלץ';

  @override
  String get detailNoBackground => 'בלי רקע';

  @override
  String get detailRitual => 'טקס „לילה טוב”';

  @override
  String get detailRitualSub => 'קודם רק הרקע, ואחרי האגדה הוא ממשיך עוד קצת';

  @override
  String get detailPlay => 'הפעלה';

  @override
  String get detailFavourite => 'מועדפת';

  @override
  String get playerIntro => 'רק רקע…';

  @override
  String get playerStartNow => 'להתחיל עכשיו';

  @override
  String get playerVoice => 'אגדה';

  @override
  String get playerTail => 'הרקע דועך';

  @override
  String get playerFadeOut => 'נעשה שקט…';

  @override
  String get playerDone => 'לילה טוב';

  @override
  String get playerMixer => 'תיבת צלילים';

  @override
  String get playerBalance => 'קול ↔ רקע';

  @override
  String get playerBackground => 'רקע';

  @override
  String get playerStop => 'עצירה';

  @override
  String get playerNothing => 'שום דבר לא מתנגן';

  @override
  String get mixerTitle => 'תיבת צלילים';

  @override
  String get mixerMain => 'צליל ראשי';

  @override
  String get mixerSecondary => 'צליל נוסף';

  @override
  String get mixerAddLayer => 'הוספת שכבה';

  @override
  String get mixerPresets => 'מיקסים שמורים';

  @override
  String get mixerSavePreset => 'שמירת מיקס';

  @override
  String get mixerPresetName => 'שם המיקס';

  @override
  String get mixerSave => 'שמירה';

  @override
  String get mixerCancel => 'ביטול';

  @override
  String get mixerDeletePreset => 'למחוק את המיקס?';

  @override
  String get mixerDelete => 'מחיקה';

  @override
  String get mixerRemoveLayer => 'הסרת שכבה';

  @override
  String get mixerGroupNature => 'צלילי טבע';

  @override
  String get mixerGroupMusic => 'שירי ערש';

  @override
  String get timerTitle => 'טיימר';

  @override
  String get timerOff => 'כבוי';

  @override
  String get timerEndOfTale => 'בסוף האגדה';

  @override
  String get settingsTitle => 'הגדרות';

  @override
  String get settingsBreathing => 'עיגול נושם';

  @override
  String get settingsBreathingSub => 'התנועה היחידה במסך הנגן';

  @override
  String get settingsIntro => 'רקע לפני האגדה (טקס)';

  @override
  String get settingsTail => 'רקע אחרי האגדה (טקס)';

  @override
  String get settingsTimer => 'טיימר ברירת מחדל';

  @override
  String get settingsCatalog => 'קטלוג';

  @override
  String get settingsCheckUpdates => 'בדיקת עדכונים';

  @override
  String get settingsChecking => 'בודק…';

  @override
  String get settingsUpToDate => 'הקטלוג מעודכן';

  @override
  String get settingsUpdated => 'הקטלוג עודכן';

  @override
  String get settingsOffline => 'אין חיבור — הכול עובד גם בלי רשת';

  @override
  String get settingsVoice => 'קול';

  @override
  String get settingsVocative => 'איך קוראים לילד';

  @override
  String get settingsVocativeSub =>
      'השם שבו את/ה קורא/ת לילד, למשל נועה. עדיין לא בשימוש.';

  @override
  String get settingsVocativeNone => 'לא הוגדר';

  @override
  String get settingsPrivacy =>
      'בלי חשבון, בלי ניתוח נתונים. הרשת משמשת רק לעדכון הקטלוג.';

  @override
  String get settingsPrivacyCloning =>
      'בלי חשבון, בלי ניתוח נתונים. הרשת משמשת רק לעדכון הקטלוג ולקול שהקלטת.';

  @override
  String get voiceTitle => 'קול';

  @override
  String get voiceSystem => 'קול הטלפון';

  @override
  String get voiceSystemSub => 'עובד מיד ובלי אינטרנט';

  @override
  String get voiceRecord => 'הקלטת הקול שלי';

  @override
  String get voiceBeta => 'ניסיון חינם. הכנת הקול שלך נמשכת כמה שעות.';

  @override
  String get voicePending => 'הקול שלך בהכנה ויהיה מוכן עד הבוקר';

  @override
  String get voiceReady => 'מוכן';

  @override
  String get voiceWaiting => 'הקול שלך מוכן, ממתינים למשפטים הראשונים';

  @override
  String get voiceFailed => 'לא ניתן ליצור את הקול שלך. כדאי להקליט שוב.';

  @override
  String get voiceDelete => 'מחיקת הקול';

  @override
  String get voiceCancel => 'ביטול';

  @override
  String get voiceMissingClips =>
      'משפטים שעדיין לא הורדו ייקראו בינתיים בקול הטלפון.';

  @override
  String get voiceHintTitle => 'אין בטלפון קול באנגלית';

  @override
  String get voiceHintIos =>
      'אפשר להתקין אחד ב„הגדרות” ← נגישות ← תוכן מוקרא ← קולות ← אנגלית (עדיף קול משופר או פרימיום).';

  @override
  String get voiceHintAndroid =>
      'אפשר להתקין אחד ב„הגדרות” ← פלט של המרת טקסט לדיבור ← Google ← התקנת נתוני קול ← אנגלית.';

  @override
  String get voiceHintOk => 'הבנתי';

  @override
  String get recTitle => 'הקלטת הקול שלי';

  @override
  String get recName => 'השם שלך';

  @override
  String get recNameHint => 'למשל מיכל';

  @override
  String get recTips => 'לפני שמתחילים';

  @override
  String get recRead => 'קראו בקול';

  @override
  String get recConsent =>
      'אני מסכים/ה ש‑Hajánek ייצור את הקול שלי מתוך ההקלטה שלי. ההקלטה והקול נשמרים רק בשרת של Hajánek, ואפשר למחוק אותם בכל עת.';

  @override
  String get recStart => 'הקלטה';

  @override
  String get recStop => 'סיום';

  @override
  String get recReadHint =>
      'בזמן ההקלטה הטקסט זז איתך. אם הוא מקדים או מפגר, הקישו על השורה שאתם קוראים.';

  @override
  String get recReadyHint => 'המשיכו לקרוא, ההקלטה תיעצר לבד אחרי 30 שנ׳';

  @override
  String get recPlay => 'האזנה';

  @override
  String get recPause => 'עצירה';

  @override
  String get recAgain => 'הקלטה מחדש';

  @override
  String get recUpload => 'שליחה';

  @override
  String get recUploading => 'שולח…';

  @override
  String get recNoMic => 'נדרשת גישה למיקרופון — אפשר לאשר אותה בהגדרות.';

  @override
  String get recFailed => 'ההקלטה לא הצליחה. נסו שוב.';

  @override
  String get pairTv => 'חיבור טלוויזיה';

  @override
  String get pairTvSub => 'כך הקול שלך יקריא את האגדות גם בטלוויזיה';

  @override
  String get pairTvHelp =>
      'בטלוויזיה פותחים Hajánek ← קול ← חיבור לטלפון. יופיע קוד בן שש ספרות.';

  @override
  String get pairCode => 'הקוד מהטלוויזיה';

  @override
  String get pairConfirm => 'חיבור';

  @override
  String get pairTvDone => 'הטלוויזיה מחוברת. הקולות יורדו אליה לבד.';

  @override
  String get pairBadCode =>
      'הקוד הזה לא תואם או שפג תוקפו. בדקו אותו בטלוויזיה.';

  @override
  String get tvVoice => 'קול';

  @override
  String get tvBackground => 'רקע';

  @override
  String get tvSettings => 'הגדרות';

  @override
  String get tvOn => 'פועל';

  @override
  String get tvOff => 'כבוי';

  @override
  String get tvPause => 'השהיה';

  @override
  String get tvResume => 'המשך';

  @override
  String get tvFavourite => 'מועדפת';

  @override
  String get tvUnfavourite => 'הסרה מהמועדפים';

  @override
  String get tvJukeboxSub => 'בחרו רקע, הוא מתנגן בלי אגדה';

  @override
  String get tvBalance => 'קול ↔ רקע';

  @override
  String get voiceSystemTv => 'קול הטלוויזיה';

  @override
  String get voiceSystemTvSub => 'בלי אינטרנט, אם הטלוויזיה מדברת אנגלית';

  @override
  String get voiceParentTvHint =>
      'קול של הורה מוקלט בטלפון. חברו את הטלוויזיה לטלפון והקולות יורדו לכאן לבד.';

  @override
  String get voiceHintTitleTv => 'אין בטלוויזיה קול באנגלית';

  @override
  String get voiceHintTv =>
      'את האגדות יכול להקריא קול של הורה: הקליטו אותו בטלפון וחברו את הטלוויזיה (קול ← חיבור לטלפון). בלעדיו מתנגן רק הרקע.';

  @override
  String get pairTitle => 'חיבור לטלפון';

  @override
  String get pairSub => 'קול של הורה מוקלט בטלפון';

  @override
  String get pairInstructions =>
      'בטלפון פותחים Hajánek ← קול ← חיבור טלוויזיה ומזינים את הקוד';

  @override
  String get pairWaiting => 'ממתין לטלפון…';

  @override
  String get pairDone => 'מחובר. הקולות יורדים עכשיו לטלוויזיה.';

  @override
  String get pairExpired => 'תוקף הקוד פג.';

  @override
  String get pairNewCode => 'קוד חדש';

  @override
  String get pairClose => 'סיום';

  @override
  String minutes(int n) {
    return '$n דק׳';
  }

  @override
  String detailAge(String age) {
    return 'גיל $age';
  }

  @override
  String playerIntroLeft(String left) {
    return 'האגדה מתחילה בעוד $left';
  }

  @override
  String get sectionUvod => 'התמקמות';

  @override
  String get sectionVstup => 'אל תוך האגדה';

  @override
  String get sectionPribeh => 'הסיפור';

  @override
  String get sectionDojezd => 'הרגעה';

  @override
  String settingsCatalogVersion(int v) {
    return 'גרסת הקטלוג $v';
  }

  @override
  String seconds(int n) {
    return '$n שנ׳';
  }

  @override
  String voiceDownloading(int done, int total) {
    return 'מוריד קול: $done מתוך $total משפטים';
  }

  @override
  String voiceDeleteConfirm(String name) {
    return 'למחוק את הקול „$name”? ההקלטה וכל המשפטים יימחקו מהטלפון ומהשרת.';
  }

  @override
  String recMinHint(int s) {
    return 'אפשר לסיים אחרי $s שנ׳';
  }

  @override
  String get balanceVoiceOnly => 'רק קול';

  @override
  String get balanceMoreVoice => 'יותר קול';

  @override
  String get balanceEven => 'מאוזן';

  @override
  String get balanceMoreBackground => 'יותר רקע';

  @override
  String get balanceBackgroundOnly => 'רק רקע';

  @override
  String get languageTitle => 'שפה';

  @override
  String get languageSub => 'שפת האפליקציה, האגדות והקול';

  @override
  String get languageSystem => 'כמו בטלפון';

  @override
  String get playerChannel => 'ניגון';

  @override
  String get languageTalesFallback =>
      'האגדות עדיין לא קיימות בשפה הזו, ולכן הן מתנגנות באנגלית.';
}
