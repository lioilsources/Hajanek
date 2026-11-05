import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../catalog/catalog_controller.dart';
import '../catalog/tale_detail_screen.dart';
import '../settings/settings_controller.dart';
import '../voice/voice_controller.dart';
import '../voice/voice_screen.dart';
import 'tv_widgets.dart';

/// TV tale detail: the title, a big Play, and one row per choice.
class TvTaleScreen extends ConsumerStatefulWidget {
  const TvTaleScreen({super.key, required this.taleId});
  final String taleId;

  @override
  ConsumerState<TvTaleScreen> createState() => _TvTaleScreenState();
}

class _TvTaleScreenState extends ConsumerState<TvTaleScreen> {
  late bool _ritual = ref.read(settingsProvider).ritual;
  String _background = defaultBackground;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider).catalog;
    final tale = catalog.tale(widget.taleId);
    if (tale == null) return const Scaffold(body: SizedBox.shrink());

    final presets = [...catalog.presets, ...?ref.watch(userPresetsProvider).value];
    final favourite = ref.watch(favouritesProvider).value?.contains(tale.id) ?? false;
    final voiceId = ref.watch(settingsProvider.select((s) => s.voiceId));
    final voices = ref.watch(voiceProvider.select((s) => s.voices));
    final choices = backgroundChoices(catalog, tale, presets);
    final background = choices.firstWhere((c) => c.$1 == _background, orElse: () => choices.first);

    return TvPage(
      title: Text(tale.title, style: kidTitleStyle(size: Tv.kidTitle)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${S.detailAge(tale.age)} · ${S.homeMinutes(tale.script().estDurationS)}',
                  style: const TextStyle(color: Night.textDim, fontSize: Tv.text),
                ),
                const SizedBox(height: 32),
                TvButton.icon(
                  key: const ValueKey('tv-play'),
                  autofocus: true,
                  filled: true,
                  icon: Icons.play_arrow,
                  label: S.detailPlay,
                  onPressed: () => playTale(context, ref,
                      tale: tale, layers: backgroundLayers(_background, tale, presets), ritual: _ritual),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
          Expanded(
            child: ListView(
              // The focused row grows a little; don't cut its border.
              clipBehavior: Clip.none,
              padding: const EdgeInsets.only(bottom: 48),
              children: [
                _Row(
                  label: S.detailVoice,
                  value: voiceLabel(voiceId, voices, tv: true),
                  onPressed: () => context.push('/voice'),
                ),
                _Row(
                  label: S.detailBackground,
                  value: background.$2,
                  onPressed: () async {
                    final picked = await showChoiceSheet<String>(
                      context: context,
                      title: S.detailBackground,
                      choices: [for (final c in choices) c.$1],
                      label: (id) => choices.firstWhere((c) => c.$1 == id).$2,
                      selected: _background,
                    );
                    if (picked != null) setState(() => _background = picked);
                  },
                ),
                _Row(
                  label: S.detailRitual,
                  value: _ritual ? S.tvOn : S.tvOff,
                  onPressed: () => setState(() => _ritual = !_ritual),
                ),
                _Row(
                  label: S.tvFavourite,
                  value: favourite ? S.tvOn : S.tvOff,
                  onPressed: () => ref.read(databaseProvider).setFavourite(tale.id, !favourite),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.onPressed});
  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TvButton(
          onPressed: onPressed,
          child: Row(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: Tv.text)),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: Tv.text, color: Night.accent),
                ),
              ),
            ],
          ),
        ),
      );
}
