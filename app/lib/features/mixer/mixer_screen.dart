import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../catalog/catalog_controller.dart';
import '../catalog/catalog_models.dart';
import '../player/player_controller.dart';
import '../timer/timer_button.dart';

class MixerScreen extends ConsumerWidget {
  const MixerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider).catalog;
    final p = ref.watch(playerProvider);
    final ctrl = ref.read(playerProvider.notifier);
    final userPresets = ref.watch(userPresetsProvider).value ?? const <MixPreset>[];
    final layers = p.layers;

    String title(String id) => catalog.ambientById(id)?.title ?? id;
    // Nature sounds first, then lullabies; catalog order within a group.
    final choices = [
      for (final k in AmbientKind.values)
        for (final a in catalog.ambient)
          if (a.kind == k) a.id,
    ];
    String group(String id) =>
        catalog.ambientById(id)?.kind == AmbientKind.music ? S.mixerGroupMusic : S.mixerGroupNature;

    void replace(int i, MixLayer l) => ctrl.setLayers([...layers]..[i] = l);

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.mixerTitle),
        actions: const [TimerButton(), SizedBox(width: 8)],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 140),
        children: [
          for (var i = 0; i < layers.length; i++) ...[
            SectionLabel(i == 0 ? S.mixerMain : S.mixerSecondary),
            ListTile(
              title: Text(title(layers[i].ambient), style: const TextStyle(fontSize: 18)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.expand_more),
                  if (i > 0)
                    IconButton(
                      tooltip: S.mixerRemoveLayer,
                      icon: const Icon(Icons.close),
                      onPressed: () => ctrl.setLayers([...layers]..removeAt(i)),
                    ),
                ],
              ),
              onTap: () async {
                final id = await showChoiceSheet<String>(
                  context: context,
                  title: i == 0 ? S.mixerMain : S.mixerSecondary,
                  choices: choices,
                  label: title,
                  group: group,
                  selected: layers[i].ambient,
                );
                if (id != null) replace(i, layers[i].copyWith(ambient: id));
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Slider(
                value: layers[i].volume,
                onChanged: (v) => replace(i, layers[i].copyWith(volume: v)),
              ),
            ),
          ],
          if (layers.length < maxMixLayers)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text(S.mixerAddLayer),
                onPressed: () {
                  final used = {for (final l in layers) l.ambient};
                  final next = catalog.ambient
                      .firstWhere((a) => !used.contains(a.id), orElse: () => catalog.ambient.first);
                  ctrl.setLayers([...layers, MixLayer(ambient: next.id, volume: 0.4)]);
                },
              ),
            ),
          const SectionLabel(S.mixerPresets),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final preset in [...catalog.presets, ...userPresets])
                  OutlinedButton(
                    onPressed: () => ctrl.setLayers(preset.layers),
                    onLongPress: preset.user ? () => _confirmDelete(context, ref, preset) : null,
                    child: Text(preset.title, style: const TextStyle(fontSize: 16)),
                  ),
                if (layers.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text(S.mixerSavePreset),
                    onPressed: () => _savePreset(context, ref, layers),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox.square(
        dimension: 96,
        child: FloatingActionButton(
          backgroundColor: Night.surfaceHigh,
          foregroundColor: Night.text,
          elevation: 0,
          shape: const CircleBorder(),
          onPressed: layers.isEmpty
              ? null
              : () => p.active ? ctrl.togglePlay() : ctrl.startMixer(),
          child: Icon(p.active && p.playing ? Icons.pause : Icons.play_arrow, size: 56),
        ),
      ),
    );
  }

  Future<void> _savePreset(BuildContext context, WidgetRef ref, List<MixLayer> layers) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(S.mixerSavePreset),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: S.mixerPresetName),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(S.mixerCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text(S.mixerSave),
          ),
        ],
      ),
    );
    controller.dispose();
    final title = name?.trim() ?? '';
    if (title.isEmpty) return;
    await ref.read(databaseProvider).saveUserPreset(MixPreset(
          id: 'user-${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          layers: layers,
          user: true,
        ));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, MixPreset preset) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${S.mixerDeletePreset} „${preset.title}“'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text(S.mixerCancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text(S.mixerDelete)),
        ],
      ),
    );
    if (ok ?? false) await ref.read(databaseProvider).deleteUserPreset(preset.id);
  }
}
