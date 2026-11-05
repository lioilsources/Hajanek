import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../player/player_controller.dart';
import '../player/player_screen.dart' show phaseLabel;
import '../player/ritual.dart';
import '../timer/sleep_timer.dart';
import '../timer/timer_button.dart';
import 'tv_widgets.dart';

/// The night picture: black, the tale's name, where it is and the timer.
/// After [hideAfter] without the remote even that fades out; the first key
/// press only brings it back. No animations — a TV in standby plays no
/// sound, so the picture has to stay on and stay dark.
class TvPlayerScreen extends ConsumerStatefulWidget {
  const TvPlayerScreen({super.key, this.hideAfter = const Duration(seconds: 10)});
  final Duration hideAfter;

  @override
  ConsumerState<TvPlayerScreen> createState() => _TvPlayerScreenState();
}

class _TvPlayerScreenState extends ConsumerState<TvPlayerScreen> {
  Timer? _timer;
  bool _hidden = false;

  /// Autofocus alone isn't enough: coming back from home ("now playing")
  /// left nothing focused and the remote did nothing.
  final _play = FocusNode(debugLabel: 'play-pause');

  /// Catches keys (wake, play/pause) when no button has focus yet.
  final _root = FocusNode(debugLabel: 'tv-player', skipTraversal: true);

  static final _playPause = {
    LogicalKeyboardKey.mediaPlayPause,
    LogicalKeyboardKey.mediaPlay,
    LogicalKeyboardKey.mediaPause,
  };

  @override
  void initState() {
    super.initState();
    _arm();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureFocus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _play.dispose();
    _root.dispose();
    super.dispose();
  }

  void _ensureFocus() {
    if (!mounted) return;
    final focused = FocusManager.instance.primaryFocus;
    final inside = focused != null && focused != _root && focused.context != null &&
        focused.context!.findAncestorStateOfType<_TvPlayerScreenState>() == this;
    if (!inside) _play.requestFocus();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(widget.hideAfter, () {
      if (mounted) setState(() => _hidden = true);
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final key = e.logicalKey;
    // Back always leaves (the sound goes on); play/pause always toggles.
    if (key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape) return KeyEventResult.ignored;
    final wasHidden = _hidden;
    if (wasHidden) setState(() => _hidden = false);
    _arm();
    _ensureFocus();
    if (_playPause.contains(key)) {
      final ctrl = ref.read(playerProvider.notifier);
      switch (key) {
        case LogicalKeyboardKey.mediaPlay:
          ctrl.resume();
        case LogicalKeyboardKey.mediaPause:
          ctrl.pause();
        default:
          ctrl.togglePlay();
      }
      return KeyEventResult.handled;
    }
    return wasHidden ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(playerProvider);
    final ctrl = ref.read(playerProvider.notifier);
    final remaining = p.timerRemaining;
    final status = [
      phaseLabel(p),
      if (p.kind == SessionKind.tale && p.phase == RitualPhase.voice) S.section(p.section),
      if (remaining != null) '${S.timerTitle} ${S.timerRemaining(remaining)}'
      else if (p.timer.kind != SleepTimerKind.off) '${S.timerTitle}: ${timerLabel(p.timer)}',
    ].where((s) => s.isNotEmpty).join(' · ');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _root,
        autofocus: true,
        onKeyEvent: _onKey,
        child: AnimatedOpacity(
          opacity: _hidden ? 0 : 1,
          duration: const Duration(seconds: 2),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  p.active ? p.title : S.playerNothing,
                  textAlign: TextAlign.center,
                  style: kidTitleStyle(size: Tv.kidTitle, color: Night.textDim),
                ),
                const SizedBox(height: 12),
                Text(status, style: const TextStyle(color: Night.textDim, fontSize: Tv.text)),
                const SizedBox(height: 40),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TvButton.icon(
                      key: const ValueKey('play-pause'),
                      focusNode: _play,
                      icon: p.playing ? Icons.pause : Icons.play_arrow,
                      label: p.playing ? S.tvPause : S.tvResume,
                      onPressed: p.active ? ctrl.togglePlay : null,
                    ),
                    if (p.kind == SessionKind.tale && p.phase == RitualPhase.intro) ...[
                      const SizedBox(width: Tv.gap),
                      TvButton.icon(icon: Icons.skip_next, label: S.playerStartNow, onPressed: ctrl.startVoiceNow),
                    ],
                    const SizedBox(width: Tv.gap),
                    TvButton.icon(
                      icon: Icons.bedtime_outlined,
                      label: S.timerTitle,
                      onPressed: () => pickTimer(context, ref),
                    ),
                    const SizedBox(width: Tv.gap),
                    TvButton.icon(
                      icon: Icons.stop,
                      label: S.playerStop,
                      onPressed: p.active ? ctrl.stop : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
