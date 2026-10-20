import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../settings/settings_controller.dart';
import '../timer/timer_button.dart';
import 'player_controller.dart';
import 'ritual.dart';

String phaseLabel(PlayerState p) => switch (p.phase) {
      _ when p.kind == SessionKind.mixer => S.mixerTitle,
      RitualPhase.idle => '',
      RitualPhase.intro => S.playerIntro,
      RitualPhase.voice => S.playerVoice,
      RitualPhase.tail => S.playerTail,
      RitualPhase.fadeOut => S.playerFadeOut,
      RitualPhase.done => S.playerDone,
    };

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(playerProvider);
    final breathing = ref.watch(settingsProvider.select((s) => s.breathing));
    final ctrl = ref.read(playerProvider.notifier);

    return Scaffold(
      body: InactivityDimmer(
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.expand_more, size: 32),
                    onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                  ),
                  const Spacer(),
                  const TimerButton(),
                  const SizedBox(width: 8),
                ],
              ),
              Expanded(
                child: Center(
                  child: breathing && p.active ? const BreathingCircle() : const SizedBox.shrink(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  p.active ? p.title : S.playerNothing,
                  textAlign: TextAlign.center,
                  style: kidTitleStyle(size: 30),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                [
                  phaseLabel(p),
                  if (p.kind == SessionKind.tale && p.phase == RitualPhase.voice) S.section(p.section),
                ].where((s) => s.isNotEmpty).join(' · '),
                style: const TextStyle(color: Night.textDim, fontSize: 16),
              ),
              if (p.kind == SessionKind.tale && p.phase == RitualPhase.voice)
                Padding(
                  padding: const EdgeInsets.fromLTRB(48, 12, 48, 0),
                  child: LinearProgressIndicator(
                    value: p.progress,
                    minHeight: 3,
                    color: Night.accentDim,
                    backgroundColor: Night.outline,
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: S.playerStop,
                    iconSize: 40,
                    style: IconButton.styleFrom(minimumSize: const Size.square(72)),
                    onPressed: p.active ? ctrl.stop : null,
                    icon: const Icon(Icons.stop),
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    key: const ValueKey('play-pause'),
                    iconSize: 64,
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(104),
                      backgroundColor: Night.surfaceHigh,
                    ),
                    onPressed: p.active ? ctrl.togglePlay : null,
                    icon: Icon(p.playing ? Icons.pause : Icons.play_arrow),
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    tooltip: S.playerBackground,
                    iconSize: 36,
                    style: IconButton.styleFrom(minimumSize: const Size.square(72)),
                    onPressed: () => context.push('/mixer'),
                    icon: const Icon(Icons.waves),
                  ),
                ],
              ),
              if (p.kind == SessionKind.tale) ...[
                const SizedBox(height: 16),
                const Text(S.playerBalance, style: TextStyle(color: Night.textDim)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Slider(value: p.balance, onChanged: ctrl.setBalance),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
