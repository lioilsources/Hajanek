import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../player/player_controller.dart';
import '../settings/settings_controller.dart';
import '../voice/voice_controller.dart';
import '../voice/voice_screen.dart';
import 'catalog_controller.dart';
import 'catalog_models.dart';

const _recommended = '_recommended';
const _none = '_none';

class TaleDetailScreen extends ConsumerStatefulWidget {
  const TaleDetailScreen({super.key, required this.taleId});
  final String taleId;

  @override
  ConsumerState<TaleDetailScreen> createState() => _TaleDetailScreenState();
}

class _TaleDetailScreenState extends ConsumerState<TaleDetailScreen> {
  late bool _ritual = ref.read(settingsProvider).ritual;
  String _background = _recommended;

  List<MixLayer> _layers(Tale tale, List<MixPreset> presets) => switch (_background) {
        _recommended => [MixLayer(ambient: tale.ambient, volume: 0.7)],
        _none => const [],
        final id => presets.firstWhere((p) => p.id == id, orElse: () => presets.first).layers,
      };

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider).catalog;
    final tale = catalog.tale(widget.taleId);
    if (tale == null) return const Scaffold(body: SizedBox.shrink());

    final presets = [...catalog.presets, ...?ref.watch(userPresetsProvider).value];
    final favourite = ref.watch(favouritesProvider).value?.contains(tale.id) ?? false;
    final voiceId = ref.watch(settingsProvider.select((s) => s.voiceId));
    final voices = ref.watch(voiceProvider.select((s) => s.voices));
    final recommendedTitle = catalog.ambientById(tale.ambient)?.title ?? tale.ambient;

    final backgroundChoices = <(String, String)>[
      (_recommended, '${S.detailRecommended}: $recommendedTitle'),
      for (final p in presets) (p.id, p.title),
      (_none, S.detailNoBackground),
    ];

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: S.detailFavourite,
            icon: Icon(favourite ? Icons.star : Icons.star_border,
                color: favourite ? Night.accent : null),
            onPressed: () => ref.read(databaseProvider).setFavourite(tale.id, !favourite),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(tale.title, style: kidTitleStyle(size: 32)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(S.detailAge(tale.age), style: const TextStyle(color: Night.textDim)),
          ),
          const SectionLabel(S.detailVoice),
          ListTile(
            title: Text(voiceLabel(voiceId, voices), style: const TextStyle(fontSize: 18)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/voice'),
          ),
          const SectionLabel(S.detailBackground),
          ListTile(
            title: Text(
              backgroundChoices.firstWhere((c) => c.$1 == _background,
                  orElse: () => backgroundChoices.first).$2,
              style: const TextStyle(fontSize: 18),
            ),
            trailing: const Icon(Icons.expand_more),
            onTap: () async {
              final picked = await showChoiceSheet<String>(
                context: context,
                title: S.detailBackground,
                choices: [for (final c in backgroundChoices) c.$1],
                label: (id) => backgroundChoices.firstWhere((c) => c.$1 == id).$2,
                selected: _background,
              );
              if (picked != null) setState(() => _background = picked);
            },
          ),
          SwitchListTile(
            title: const Text(S.detailRitual, style: TextStyle(fontSize: 18)),
            subtitle: const Text(S.detailRitualSub),
            value: _ritual,
            onChanged: (v) => setState(() => _ritual = v),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(72)),
              icon: const Icon(Icons.play_arrow, size: 32),
              label: const Text(S.detailPlay, style: TextStyle(fontSize: 22)),
              onPressed: () async {
                ref.read(settingsProvider.notifier).update((s) => s.copyWith(ritual: _ritual));
                final ok = await ref.read(playerProvider.notifier).startTale(
                      tale: tale,
                      layers: _layers(tale, presets),
                      ritual: _ritual,
                    );
                if (!context.mounted) return;
                if (ok) {
                  context.push('/player');
                } else {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text(S.detailNoScript)));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
