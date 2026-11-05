import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../player/system_tts.dart';
import '../settings/settings_controller.dart';
import '../voice/voice_api.dart';
import '../voice/voice_controller.dart';
import '../voice/voice_screen.dart';
import 'tv_widgets.dart';

/// TV voice choice. No recording: the parent's voice comes from the phone
/// through pairing (CONTRACTS §6).
class TvVoiceScreen extends ConsumerStatefulWidget {
  const TvVoiceScreen({super.key});

  @override
  ConsumerState<TvVoiceScreen> createState() => _TvVoiceScreenState();
}

class _TvVoiceScreenState extends ConsumerState<TvVoiceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(voiceProvider.notifier)
        ..startPolling()
        ..refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final voices = ref.watch(voiceProvider);
    final selected = ref.watch(settingsProvider.select((s) => s.voiceId));
    final czech = ref.watch(czechVoiceAvailableProvider).value;
    void select(String id) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(voiceId: id));

    Widget choice(String key, String title, String sub, String id, {bool autofocus = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TvButton(
            key: ValueKey(key),
            autofocus: autofocus,
            onPressed: () => select(id),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: id == selected ? const Icon(Icons.check, color: Night.accent) : null,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: Tv.text)),
                      Text(sub, style: const TextStyle(color: Night.textDim, fontSize: Tv.textSmall)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return TvPage(
      title: const Text(S.voiceTitle, style: TextStyle(fontSize: Tv.title)),
      actions: [
        TvButton.icon(
          key: const ValueKey('tv-pair'),
          icon: Icons.phonelink,
          label: S.pairTitle,
          onPressed: () => showDialog<void>(context: context, builder: (_) => const PairingDialog()),
        ),
      ],
      child: ListView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          choice('voice-system', S.voiceSystemTv,
              czech == false ? S.czechHintTitleTv : S.voiceSystemTvSub, systemVoiceId,
              autofocus: true),
          for (final v in voices.voices) choice('voice-${v.id}', v.name, voiceStatusText(v), v.id),
          const SizedBox(height: 12),
          Text(
            czech == false ? S.czechHintTv : S.voiceParentTvHint,
            style: const TextStyle(color: Night.textDim, fontSize: Tv.textSmall),
          ),
          if (voices.message != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(voices.message!, style: const TextStyle(color: Night.textDim, fontSize: Tv.textSmall)),
            ),
        ],
      ),
    );
  }
}

enum _Pairing { loading, waiting, claimed, expired, failed }

/// Shows a code and waits until the phone claims it.
class PairingDialog extends ConsumerStatefulWidget {
  const PairingDialog({super.key, this.pollEvery = const Duration(seconds: 3)});
  final Duration pollEvery;

  @override
  ConsumerState<PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends ConsumerState<PairingDialog> {
  var _state = _Pairing.loading;
  PairingCode? _code;
  String? _message;
  Timer? _poll;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    _poll?.cancel();
    final api = ref.read(voiceApiProvider);
    setState(() {
      _state = _Pairing.loading;
      _message = null;
    });
    if (api == null) return _fail(msgOffline);
    try {
      final code = await api.createPairing();
      if (!mounted) return;
      setState(() {
        _code = code;
        _state = _Pairing.waiting;
      });
      _poll = Timer.periodic(widget.pollEvery, (_) => _check(api));
    } on VoiceApiException catch (e) {
      _fail(e.message);
    }
  }

  Future<void> _check(VoiceApi api) async {
    final code = _code;
    if (_checking || code == null) return;
    if (DateTime.now().isAfter(code.expiresAt)) return _expire();
    _checking = true;
    try {
      if (!await api.pairingClaimed(code.code) || !mounted) return;
      _poll?.cancel();
      setState(() => _state = _Pairing.claimed);
      ref.read(voiceProvider.notifier)
        ..startPolling()
        ..refresh();
    } on VoiceApiException catch (e) {
      // 404 = the code expired or was replaced; a network blip just waits.
      if (e.status == 404) _expire();
    } finally {
      _checking = false;
    }
  }

  void _expire() {
    _poll?.cancel();
    if (mounted) setState(() => _state = _Pairing.expired);
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _state = _Pairing.failed;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    final body = switch (_state) {
      _Pairing.loading => const Center(child: CircularProgressIndicator()),
      _Pairing.waiting => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(S.pairInstructions, textAlign: TextAlign.center, style: TextStyle(fontSize: Tv.text)),
            const SizedBox(height: 24),
            Text(
              S.pairCodeSpaced(code!.code),
              key: const ValueKey('pair-code'),
              style: const TextStyle(fontSize: 64, letterSpacing: 8, color: Night.accent),
            ),
            const SizedBox(height: 16),
            const Text(S.pairWaiting, style: TextStyle(color: Night.textDim, fontSize: Tv.textSmall)),
          ],
        ),
      _Pairing.claimed => const Text(S.pairDone, textAlign: TextAlign.center, style: TextStyle(fontSize: Tv.text)),
      _Pairing.expired => const Text(S.pairExpired, textAlign: TextAlign.center, style: TextStyle(fontSize: Tv.text)),
      _Pairing.failed => Text(_message ?? msgServer, textAlign: TextAlign.center, style: const TextStyle(fontSize: Tv.text)),
    };
    final retry = _state == _Pairing.expired || _state == _Pairing.failed;
    return AlertDialog(
      title: const Text(S.pairTitle, style: TextStyle(fontSize: Tv.title)),
      content: SizedBox(width: 560, child: body),
      actions: [
        if (retry) TvButton(autofocus: true, onPressed: _start, child: const Text(S.pairNewCode)),
        TvButton(
          autofocus: !retry,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(S.pairClose),
        ),
      ],
    );
  }
}
