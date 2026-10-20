import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../catalog/catalog_controller.dart';
import '../timer/sleep_timer.dart';
import '../timer/timer_button.dart';
import '../voice/voice_controller.dart';
import '../voice/voice_screen.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final catalog = ref.watch(catalogProvider);

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
      appBar: AppBar(title: const Text(S.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SwitchListTile(
            title: const Text(S.settingsBreathing, style: TextStyle(fontSize: 18)),
            subtitle: const Text(S.settingsBreathingSub),
            value: s.breathing,
            onChanged: (v) => ctrl.update((s) => s.copyWith(breathing: v)),
          ),
          ListTile(
            title: const Text(S.settingsIntro, style: TextStyle(fontSize: 18)),
            trailing: Text(S.settingsSeconds(s.introSeconds), style: const TextStyle(fontSize: 16)),
            onTap: () => pick<int>(S.settingsIntro, AppSettings.introChoices, S.settingsSeconds,
                s.introSeconds, (s, v) => s.copyWith(introSeconds: v)),
          ),
          ListTile(
            title: const Text(S.settingsTail, style: TextStyle(fontSize: 18)),
            trailing: Text(S.settingsMinutes(s.tailMinutes), style: const TextStyle(fontSize: 16)),
            onTap: () => pick<int>(S.settingsTail, AppSettings.tailChoices, S.settingsMinutes,
                s.tailMinutes, (s, v) => s.copyWith(tailMinutes: v)),
          ),
          ListTile(
            title: const Text(S.settingsTimer, style: TextStyle(fontSize: 18)),
            trailing: Text(timerLabel(s.timer), style: const TextStyle(fontSize: 16)),
            onTap: () => pick<SleepTimerOption>(S.settingsTimer, SleepTimerOption.choices,
                timerLabel, s.timer, (s, v) => s.copyWith(timer: v)),
          ),
          ListTile(
            title: const Text(S.settingsVoice, style: TextStyle(fontSize: 18)),
            trailing: Text(voiceLabel(s.voiceId, ref.watch(voiceProvider).voices),
                style: const TextStyle(fontSize: 16)),
            onTap: () => context.push('/voice'),
          ),
          ListTile(
            title: const Text(S.settingsVocative, style: TextStyle(fontSize: 18)),
            subtitle: const Text(S.settingsVocativeSub),
            trailing: Text(s.vocative.isEmpty ? S.settingsVocativeNone : s.vocative,
                style: const TextStyle(fontSize: 16)),
            onTap: () async {
              final v = await _askVocative(context, s.vocative);
              if (v != null) ctrl.update((s) => s.copyWith(vocative: v.trim()));
            },
          ),
          const SectionLabel(S.settingsCatalog),
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
              child: const Text(S.settingsCheckUpdates),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 32, 20, 0),
            child: Text(S.settingsPrivacy, style: TextStyle(color: Night.textDim)),
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
      title: const Text(S.settingsVocative),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Aničko'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text(S.mixerCancel)),
        TextButton(onPressed: () => Navigator.pop(context, c.text), child: const Text(S.mixerSave)),
      ],
    ),
  );
}
