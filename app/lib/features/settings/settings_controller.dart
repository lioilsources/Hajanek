import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/strings.dart';
import '../catalog/catalog_models.dart';
import '../player/ritual.dart';
import '../player/system_tts.dart';
import '../timer/sleep_timer.dart';

class AppSettings {
  const AppSettings({
    this.breathing = true,
    this.ritual = true,
    this.introSeconds = 60,
    this.tailMinutes = 20,
    this.timer = const SleepTimerOption.off(),
    this.balance = 0.5,
    this.voiceId = systemVoiceId,
    this.vocative = '',
    this.czechHintDismissed = false,
    this.lang = '',
    this.lastMix = const [MixLayer(ambient: 'sea', volume: 0.7)],
  });

  final bool breathing;
  final bool ritual;
  final int introSeconds;
  final int tailMinutes;
  final SleepTimerOption timer;

  /// 0 = only voice, 1 = only background, 0.5 = both at full.
  final double balance;

  /// `system` (the phone's voice) or the id of a parent's cloned voice.
  final String voiceId;

  /// The child's name in the 5th case (“Aničko”); empty = script fallback.
  final String vocative;
  final bool czechHintDismissed;

  /// Language of the UI, tales and system voice (docs/I18N_PLAN.md);
  /// empty = follow the phone.
  final String lang;
  final List<MixLayer> lastMix;

  static const introChoices = [30, 60, 90, 120];
  static const tailChoices = [0, 10, 20, 30];

  RitualConfig ritualConfig({required bool enabled}) => enabled
      ? RitualConfig(
          intro: Duration(seconds: introSeconds),
          tail: Duration(minutes: tailMinutes),
        )
      : const RitualConfig.off();

  AppSettings copyWith({
    bool? breathing,
    bool? ritual,
    int? introSeconds,
    int? tailMinutes,
    SleepTimerOption? timer,
    double? balance,
    String? voiceId,
    String? vocative,
    bool? czechHintDismissed,
    String? lang,
    List<MixLayer>? lastMix,
  }) =>
      AppSettings(
        breathing: breathing ?? this.breathing,
        ritual: ritual ?? this.ritual,
        introSeconds: introSeconds ?? this.introSeconds,
        tailMinutes: tailMinutes ?? this.tailMinutes,
        timer: timer ?? this.timer,
        balance: balance ?? this.balance,
        voiceId: voiceId ?? this.voiceId,
        vocative: vocative ?? this.vocative,
        czechHintDismissed: czechHintDismissed ?? this.czechHintDismissed,
        lang: lang ?? this.lang,
        lastMix: lastMix ?? this.lastMix,
      );

  Map<String, String> toValues() => {
        'breathing': '$breathing',
        'ritual': '$ritual',
        'intro_s': '$introSeconds',
        'tail_min': '$tailMinutes',
        'timer': '${timer.code}',
        'balance': '$balance',
        'voice_id': voiceId,
        'vocative': vocative,
        'czech_hint_dismissed': '$czechHintDismissed',
        'lang': lang,
        'last_mix': jsonEncode([for (final l in lastMix) l.toJson()]),
      };

  factory AppSettings.fromValues(Map<String, String> v) {
    const d = AppSettings();
    List<MixLayer> mix() {
      try {
        final list = [
          for (final l in jsonDecode(v['last_mix']!) as List)
            MixLayer.fromJson(l as Map<String, dynamic>),
        ];
        return list.isEmpty ? d.lastMix : list.take(maxMixLayers).toList();
      } on Object {
        return d.lastMix;
      }
    }

    return AppSettings(
      breathing: v['breathing'] == null ? d.breathing : v['breathing'] == 'true',
      ritual: v['ritual'] == null ? d.ritual : v['ritual'] == 'true',
      introSeconds: int.tryParse(v['intro_s'] ?? '') ?? d.introSeconds,
      tailMinutes: int.tryParse(v['tail_min'] ?? '') ?? d.tailMinutes,
      timer: SleepTimerOption.fromCode(int.tryParse(v['timer'] ?? '') ?? 0),
      balance: (double.tryParse(v['balance'] ?? '') ?? d.balance).clamp(0.0, 1.0),
      voiceId: v['voice_id'] ?? d.voiceId,
      vocative: v['vocative'] ?? d.vocative,
      czechHintDismissed: v['czech_hint_dismissed'] == 'true',
      lang: supportedLangs.contains(v['lang']) ? v['lang']! : '',
      lastMix: v['last_mix'] == null ? d.lastMix : mix(),
    );
  }
}

/// Loaded once in main() and overridden there.
final initialSettingsProvider = Provider<AppSettings>((ref) => const AppSettings());

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  void update(AppSettings Function(AppSettings) f) {
    final old = state.toValues();
    state = f(state);
    final db = ref.read(databaseProvider);
    for (final e in state.toValues().entries) {
      if (old[e.key] != e.value) db.writeValue(e.key, e.value);
    }
  }
}

/// The phone's preferred supported language; overridden in tests.
final deviceLangProvider = Provider<String>((ref) => langFor(PlatformDispatcher.instance.locales));

/// The language in use: the parent's choice, else the phone's.
final contentLangProvider = Provider<String>((ref) {
  final chosen = ref.watch(settingsProvider.select((s) => s.lang));
  return chosen.isEmpty ? ref.watch(deviceLangProvider) : chosen;
});
