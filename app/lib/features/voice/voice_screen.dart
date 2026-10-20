import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../player/system_tts.dart';
import '../settings/settings_controller.dart';
import 'voice_api.dart';
import 'voice_controller.dart';

String voiceStatusText(LocalVoice v) => switch (v.status) {
      VoiceStatus.failed => S.voiceFailed,
      VoiceStatus.ready when v.complete => S.voiceReady,
      VoiceStatus.ready when v.total > 0 => S.voiceDownloading(v.done, v.total),
      VoiceStatus.ready => S.voiceWaiting,
      _ => S.voicePending,
    };

/// Display name of the selected voice (for the tale detail).
String voiceLabel(String voiceId, List<LocalVoice> voices) {
  if (voiceId == systemVoiceId) return S.voiceSystem;
  for (final v in voices) {
    if (v.id == voiceId) return v.name;
  }
  return S.voiceSystem;
}

class VoiceScreen extends ConsumerStatefulWidget {
  const VoiceScreen({super.key});

  @override
  ConsumerState<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends ConsumerState<VoiceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = ref.read(voiceProvider.notifier)..startPolling();
      ctrl.refresh();
    });
  }

  Future<void> _delete(LocalVoice v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(S.voiceDeleteConfirm(v.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(S.voiceCancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text(S.voiceDelete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(voiceProvider.notifier).delete(v.id);
    } on VoiceApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final voices = ref.watch(voiceProvider);
    final selected = ref.watch(settingsProvider.select((s) => s.voiceId));
    final czech = ref.watch(czechVoiceAvailableProvider).value;
    void select(String id) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(voiceId: id));
    final cloned = voices.voices.where((v) => v.id == selected).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text(S.voiceTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (czech == false) const CzechVoiceHint(),
          ListTile(
            key: const ValueKey('voice-system'),
            title: const Text(S.voiceSystem, style: TextStyle(fontSize: 18)),
            subtitle: const Text(S.voiceSystemSub),
            trailing: selected == systemVoiceId ? const Icon(Icons.check, color: Night.accent) : null,
            onTap: () => select(systemVoiceId),
          ),
          for (final v in voices.voices)
            ListTile(
              key: ValueKey('voice-${v.id}'),
              title: Text(v.name, style: const TextStyle(fontSize: 18)),
              subtitle: Text(voiceStatusText(v)),
              leading: v.id == selected ? const Icon(Icons.check, color: Night.accent) : const SizedBox(width: 24),
              trailing: IconButton(
                tooltip: S.voiceDelete,
                icon: const Icon(Icons.delete_outline),
                onPressed: voices.busy ? null : () => _delete(v),
              ),
              onTap: () => select(v.id),
            ),
          if (cloned != null && !cloned.complete)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(S.voiceMissingClips, style: TextStyle(color: Night.textDim)),
            ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(Night.tap)),
              icon: const Icon(Icons.mic_none),
              label: const Text(S.voiceRecord, style: TextStyle(fontSize: 18)),
              onPressed: voices.busy ? null : () => context.push('/voice/record'),
            ),
          ),
          if (voices.message != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Text(voices.message!, style: const TextStyle(color: Night.textDim)),
            ),
        ],
      ),
    );
  }
}

/// How to install a Czech system voice; shown when flutter_tts finds none.
class CzechVoiceHint extends StatelessWidget {
  const CzechVoiceHint({super.key, this.onDismiss});
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(S.czechHintTitle, style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text(
                defaultTargetPlatform == TargetPlatform.iOS ? S.czechHintIos : S.czechHintAndroid,
                style: const TextStyle(color: Night.textDim),
              ),
              if (onDismiss != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: onDismiss, child: const Text(S.czechHintOk)),
                ),
            ],
          ),
        ),
      );
}
