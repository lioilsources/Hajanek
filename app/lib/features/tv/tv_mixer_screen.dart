import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../catalog/catalog_controller.dart';
import '../catalog/catalog_models.dart';
import '../player/player_controller.dart';
import 'tv_widgets.dart';

/// TV jukebox: presets only. Three volume sliders on a remote are torture;
/// mixes are made on the phone (or come with the catalog).
class TvMixerScreen extends ConsumerWidget {
  const TvMixerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider).catalog;
    final user = ref.watch(userPresetsProvider).value ?? const <MixPreset>[];
    final ctrl = ref.read(playerProvider.notifier);
    final presets = [...catalog.presets, ...user];

    Future<void> play(MixPreset preset) async {
      // A running tale keeps playing with the new background.
      ctrl.setLayers(preset.layers);
      if (!ref.read(playerProvider).active) await ctrl.startMixer();
      if (context.mounted) context.push('/player');
    }

    return TvPage(
      title: Text(S.mixerTitle, style: TextStyle(fontSize: Tv.title)),
      child: ListView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          Text(S.tvJukeboxSub, style: TextStyle(color: Night.textDim, fontSize: Tv.textSmall)),
          const SizedBox(height: 24),
          Wrap(
            spacing: Tv.gap,
            runSpacing: Tv.gap,
            children: [
              for (final (i, p) in presets.indexed)
                TvButton(
                  key: ValueKey('preset-${p.id}'),
                  autofocus: i == 0,
                  onPressed: () => play(p),
                  child: Text(p.title, style: const TextStyle(fontSize: Tv.text)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
