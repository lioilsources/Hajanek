import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ol1n_telemetry/ol1n_telemetry.dart';

import '../../core/form_factor.dart';
import '../../core/strings.dart';
import '../../core/telemetry.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../catalog/catalog_controller.dart';
import '../player/player_controller.dart';
import '../timer/sleep_timer.dart';
import '../timer/timer_button.dart';
import '../voice/voice_controller.dart';
import '../voice/voice_screen.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final catalog = ref.watch(catalogProvider);
    final tv = ref.watch(formFactorProvider) == FormFactor.tv;

    Future<void> pick<T>(String title, List<T> choices, String Function(T) label, T selected,
        AppSettings Function(AppSettings, T) apply) async {
      final v = await showChoiceSheet<T>(
          context: context, title: title, choices: choices, label: label, selected: selected);
      if (v != null) ctrl.update((s) => apply(s, v));
    }

    final syncText = switch (catalog.sync) {
      SyncStatus.idle => null,
      SyncStatus.checking => S.settingsChecking,
      SyncStatus.upToDate => S.settingsUpToDate,
      SyncStatus.updated => S.settingsUpdated,
      SyncStatus.offline => S.settingsOffline,
    };

    return Scaffold(
      appBar: AppBar(title: Text(S.settingsTitle)),
      body: ListView(
        // TVs cut the screen edges (overscan).
        padding: tv ? const EdgeInsets.fromLTRB(32, 0, 32, 32) : const EdgeInsets.only(bottom: 32),
        children: [
          // The TV night picture has no breathing circle.
          if (!tv)
            SwitchListTile(
              title: Text(S.settingsBreathing, style: TextStyle(fontSize: 18)),
              subtitle: Text(S.settingsBreathingSub),
              value: s.breathing,
              onChanged: (v) => ctrl.update((s) => s.copyWith(breathing: v)),
            ),
          ListTile(
            title: Text(S.settingsIntro, style: TextStyle(fontSize: 18)),
            trailing: Text(S.settingsSeconds(s.introSeconds), style: const TextStyle(fontSize: 16)),
            onTap: () => pick<int>(S.settingsIntro, AppSettings.introChoices, S.settingsSeconds,
                s.introSeconds, (s, v) => s.copyWith(introSeconds: v)),
          ),
          ListTile(
            title: Text(S.settingsTail, style: TextStyle(fontSize: 18)),
            trailing: Text(S.settingsMinutes(s.tailMinutes), style: const TextStyle(fontSize: 16)),
            onTap: () => pick<int>(S.settingsTail, AppSettings.tailChoices, S.settingsMinutes,
                s.tailMinutes, (s, v) => s.copyWith(tailMinutes: v)),
          ),
          ListTile(
            title: Text(S.settingsTimer, style: TextStyle(fontSize: 18)),
            trailing: Text(timerLabel(s.timer), style: const TextStyle(fontSize: 16)),
            onTap: () => pick<SleepTimerOption>(S.settingsTimer, SleepTimerOption.choices,
                timerLabel, s.timer, (s, v) {
              if (v.kind != SleepTimerKind.off) Telemetry.feature('timer');
              Telemetry.track('timer_set', {'timer': telemetryTimer(v), 'during': 'settings'});
              return s.copyWith(timer: v);
            }),
          ),
          ListTile(
            title: Text(S.languageTitle, style: TextStyle(fontSize: 18)),
            subtitle: Text(S.languageSub),
            trailing: Text(s.lang.isEmpty ? S.languageSystem : langNames[s.lang]!,
                style: const TextStyle(fontSize: 16)),
            onTap: () async {
              final v = await showChoiceSheet<String>(
                context: context,
                title: S.languageTitle,
                choices: ['', ...supportedLangs],
                label: (l) => l.isEmpty ? S.languageSystem : langNames[l]!,
                selected: s.lang,
              );
              if (v == null) return;
              if (v != s.lang) Telemetry.feature('lang');
              ref.read(settingsProvider.notifier).update((s) => s.copyWith(lang: v));
            },
          ),
          ListTile(
            title: Text(S.settingsVoice, style: TextStyle(fontSize: 18)),
            trailing: Text(voiceLabel(s.voiceId, ref.watch(voiceProvider).voices, tv: tv),
                style: const TextStyle(fontSize: 16)),
            onTap: () => context.push('/voice'),
          ),
          // On a phone this is a slider in the player; a remote gets steps.
          if (tv)
            ListTile(
              title: Text(S.tvBalance, style: TextStyle(fontSize: 18)),
              trailing: Text(S.tvBalanceLabel(s.balance), style: const TextStyle(fontSize: 16)),
              onTap: () async {
                final v = await showChoiceSheet<double>(
                  context: context,
                  title: S.tvBalance,
                  choices: const [0, 0.25, 0.5, 0.75, 1],
                  label: S.tvBalanceLabel,
                  selected: (s.balance * 4).round() / 4,
                );
                if (v == null) return;
                ref.read(playerProvider.notifier)
                  ..setBalance(v)
                  ..balanceChosen();
              },
            ),
          ListTile(
            title: Text(S.settingsVocative, style: TextStyle(fontSize: 18)),
            subtitle: Text(S.settingsVocativeSub),
            trailing: Text(s.vocative.isEmpty ? S.settingsVocativeNone : s.vocative,
                style: const TextStyle(fontSize: 16)),
            onTap: () async {
              final v = await _askVocative(context, s.vocative);
              if (v != null) ctrl.update((s) => s.copyWith(vocative: v.trim()));
            },
          ),
          SectionLabel(S.settingsCatalog),
          ListTile(
            title: Text(S.settingsCatalogVersion(catalog.catalog.version)),
            subtitle: syncText == null ? null : Text(syncText),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: catalog.sync == SyncStatus.checking
                  ? null
                  : () => ref.read(catalogProvider.notifier).sync(),
              child: Text(S.settingsCheckUpdates),
            ),
          ),
          // A build without a key sends nothing: no switch to show.
          if (Telemetry.isConfigured)
            SwitchListTile(
              title: Text(S.settingsStats, style: TextStyle(fontSize: 18)),
              subtitle: Text(S.settingsStatsSub),
              value: Telemetry.isEnabled,
              onChanged: (on) async {
                await Telemetry.setEnabled(on);
                if (mounted) setState(() {});
              },
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
            child: Text(
              ref.watch(voiceCloningProvider) ? S.settingsPrivacyCloning : S.settingsPrivacy,
              style: const TextStyle(color: Night.textDim),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> _askVocative(BuildContext context, String current) {
  final c = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(S.settingsVocative),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Aničko'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(S.mixerCancel)),
        TextButton(onPressed: () => Navigator.pop(context, c.text), child: Text(S.mixerSave)),
      ],
    ),
  );
}
