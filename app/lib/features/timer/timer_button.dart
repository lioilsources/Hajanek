import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../core/widgets.dart';
import '../player/player_controller.dart';
import 'sleep_timer.dart';

String timerLabel(SleepTimerOption o) => switch (o.kind) {
      SleepTimerKind.off => S.timerOff,
      SleepTimerKind.endOfTale => S.timerEndOfTale,
      SleepTimerKind.minutes => S.timerMinutes(o.minutes),
    };

/// Picker for the sleep timer of the current session.
Future<void> pickTimer(BuildContext context, WidgetRef ref) async {
  final p = ref.read(playerProvider);
  final choice = await showChoiceSheet<SleepTimerOption>(
    context: context,
    title: S.timerTitle,
    choices: [
      for (final c in SleepTimerOption.choices)
        if (c.kind != SleepTimerKind.endOfTale || p.kind != SessionKind.mixer) c,
    ],
    label: timerLabel,
    selected: p.timer,
  );
  if (choice != null) ref.read(playerProvider.notifier).setTimer(choice);
}

/// Shows the remaining time (or the chosen option) and opens the picker.
class TimerButton extends ConsumerWidget {
  const TimerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(playerProvider);
    final remaining = p.timerRemaining;
    final text = remaining != null
        ? S.timerRemaining(remaining)
        : p.timer.kind == SleepTimerKind.off
            ? S.timerTitle
            : timerLabel(p.timer);
    return TextButton.icon(
      onPressed: () => pickTimer(context, ref),
      icon: const Icon(Icons.bedtime_outlined),
      label: Text(text, style: const TextStyle(fontSize: 16)),
    );
  }
}
