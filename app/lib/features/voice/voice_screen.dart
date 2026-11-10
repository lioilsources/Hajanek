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
String voiceLabel(String voiceId, List<LocalVoice> voices, {bool tv = false}) {
  final system = tv ? S.voiceSystemTv : S.voiceSystem;
  if (voiceId == systemVoiceId) return system;
  for (final v in voices) {
    if (v.id == voiceId) return v.name;
  }
  return system;
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(S.voiceCancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(S.voiceDelete)),
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
    final czech = ref.watch(systemVoiceAvailableProvider).value;
    void select(String id) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(voiceId: id));
    final cloned = voices.voices.where((v) => v.id == selected).firstOrNull;
    final cloning = ref.watch(voiceCloningProvider);

    return Scaffold(
      appBar: AppBar(title: Text(S.voiceTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (czech == false) const CzechVoiceHint(),
          ListTile(
            key: const ValueKey('voice-system'),
            title: Text(S.voiceSystem, style: TextStyle(fontSize: 18)),
            subtitle: Text(S.voiceSystemSub),
            trailing: selected == systemVoiceId ? const Icon(Icons.check, color: Night.accent) : null,
            onTap: () => select(systemVoiceId),
          ),
          for (final v in voices.voices)
            ListTile(
              key: ValueKey('voice-${v.id}'),
              title: Text(v.name, style: const TextStyle(fontSize: 18)),
              subtitle: Text(voiceStatusText(v)),
              leading: v.id == selected ? const Icon(Icons.check, color: Night.accent) : const SizedBox(width: 24),
              trailing: v.owned
                  ? IconButton(
                      tooltip: S.voiceDelete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: voices.busy ? null : () => _delete(v),
                    )
                  : null,
              onTap: () => select(v.id),
            ),
          if (cloned != null && !cloned.complete)
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(S.voiceMissingClips, style: TextStyle(color: Night.textDim)),
            ),
          if (cloning) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(Night.tap)),
                icon: const Icon(Icons.mic_none),
                label: Text(S.voiceRecord, style: TextStyle(fontSize: 18)),
                onPressed: voices.busy ? null : () => context.push('/voice/record'),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(S.voiceBeta, style: TextStyle(color: Night.textDim)),
            ),
            const SizedBox(height: 16),
            ListTile(
              key: const ValueKey('pair-tv'),
              leading: const Icon(Icons.tv),
              title: Text(S.pairTv, style: TextStyle(fontSize: 18)),
              subtitle: Text(S.pairTvSub),
              onTap: () => showDialog<void>(context: context, builder: (_) => const ClaimTvDialog()),
            ),
          ],
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

/// Phone side of pairing: type the code the TV shows.
class ClaimTvDialog extends ConsumerStatefulWidget {
  const ClaimTvDialog({super.key});

  @override
  ConsumerState<ClaimTvDialog> createState() => _ClaimTvDialogState();
}

class _ClaimTvDialogState extends ConsumerState<ClaimTvDialog> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String get _digits => _code.text.replaceAll(RegExp(r'\D'), '');

  Future<void> _claim() async {
    final api = ref.read(voiceApiProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (api == null) throw VoiceApiException(msgOffline);
      await api.claimPairing(_digits);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(S.pairTvDone)));
    } on VoiceApiException catch (e) {
      if (mounted) setState(() => _error = e.status == 404 || e.status == 409 ? S.pairBadCode : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(S.pairTv),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.pairTvHelp, style: TextStyle(color: Night.textDim)),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('pair-code-field'),
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 28, letterSpacing: 6),
              decoration: InputDecoration(labelText: S.pairCode, errorText: _error, errorMaxLines: 3),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(S.voiceCancel)),
          TextButton(
            onPressed: _busy || _digits.length != 6 ? null : _claim,
            child: Text(S.pairConfirm),
          ),
        ],
      );
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
              Text(S.voiceHintTitle, style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text(
                defaultTargetPlatform == TargetPlatform.iOS ? S.voiceHintIos : S.voiceHintAndroid,
                style: const TextStyle(color: Night.textDim),
              ),
              if (onDismiss != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(onPressed: onDismiss, child: Text(S.voiceHintOk)),
                ),
            ],
          ),
        ),
      );
}
