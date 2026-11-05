import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../catalog/catalog_controller.dart';
import '../catalog/catalog_models.dart';
import '../player/player_controller.dart';
import '../settings/settings_controller.dart';
import '../voice/voice_controller.dart';
import 'tv_widgets.dart';

/// TV home: a grid of tales under a row of the few other places.
class TvHomeScreen extends ConsumerWidget {
  const TvHomeScreen({super.key});

  static const columns = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final favourites = ref.watch(favouritesProvider).value ?? const <String>{};
    final hintDismissed = ref.watch(settingsProvider.select((s) => s.czechHintDismissed));
    final czech = ref.watch(czechVoiceAvailableProvider).value;
    final player = ref.watch(playerProvider);

    final tales = [...catalog.catalog.tales]
      ..sort((a, b) {
        final fa = favourites.contains(a.id) ? 0 : 1;
        final fb = favourites.contains(b.id) ? 0 : 1;
        return fa != fb ? fa - fb : 0;
      });

    return TvPage(
      title: Text(S.appName, style: kidTitleStyle(size: Tv.kidTitle, color: Night.accent)),
      actions: [
        TvButton.icon(icon: Icons.record_voice_over_outlined, label: S.tvVoice, onPressed: () => context.push('/voice')),
        TvButton.icon(icon: Icons.waves, label: S.tvBackground, onPressed: () => context.push('/mixer')),
        TvButton.icon(icon: Icons.tune, label: S.tvSettings, onPressed: () => context.push('/settings')),
      ],
      child: LayoutBuilder(
        builder: (context, box) {
          final w = (box.maxWidth - Tv.gap * (columns - 1)) / columns;
          return ListView(
            // The focused card grows a little; don't cut its border.
            clipBehavior: Clip.none,
            padding: const EdgeInsets.only(bottom: 48, top: 8),
            children: [
              if (player.active) ...[
                TvButton.icon(
                  key: const ValueKey('tv-now-playing'),
                  autofocus: true,
                  icon: player.playing ? Icons.graphic_eq : Icons.pause,
                  label: '${S.homeNowPlaying}: ${player.title}',
                  onPressed: () => context.push('/player'),
                ),
                const SizedBox(height: 24),
              ],
              if (czech == false && !hintDismissed) ...[
                _CzechHintTv(
                  onDismiss: () => ref
                      .read(settingsProvider.notifier)
                      .update((s) => s.copyWith(czechHintDismissed: true)),
                ),
                const SizedBox(height: 24),
              ],
              Wrap(
                spacing: Tv.gap,
                runSpacing: Tv.gap,
                children: [
                  for (final (i, t) in tales.indexed)
                    SizedBox(
                      width: w,
                      height: 140,
                      child: _TaleCard(
                        tale: t,
                        favourite: favourites.contains(t.id),
                        autofocus: i == 0 && !player.active,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TaleCard extends StatelessWidget {
  const _TaleCard({required this.tale, required this.favourite, required this.autofocus});
  final Tale tale;
  final bool favourite;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TvButton(
        key: ValueKey('tale-${tale.id}'),
        autofocus: autofocus,
        padding: const EdgeInsets.all(20),
        onPressed: () => context.push('/tale/${tale.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(tale.title, style: kidTitleStyle(size: 22), maxLines: 3, overflow: TextOverflow.fade),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${S.detailAge(tale.age)} · ${S.homeMinutes(tale.script().estDurationS)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Night.textDim, fontSize: Tv.textSmall),
                  ),
                ),
                if (favourite) const Icon(Icons.star, color: Night.accent),
              ],
            ),
          ],
        ),
      );
}

class _CzechHintTv extends StatelessWidget {
  const _CzechHintTv({required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Night.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.czechHintTitleTv, style: TextStyle(fontSize: Tv.text)),
                  SizedBox(height: 8),
                  Text(S.czechHintTv, style: TextStyle(color: Night.textDim, fontSize: Tv.textSmall)),
                ],
              ),
            ),
            const SizedBox(width: 24),
            TvButton(onPressed: onDismiss, child: const Text(S.czechHintOk, style: TextStyle(fontSize: Tv.text))),
          ],
        ),
      );
}
