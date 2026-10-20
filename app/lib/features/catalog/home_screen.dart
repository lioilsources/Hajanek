import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../player/player_controller.dart';
import '../settings/settings_controller.dart';
import 'catalog_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final favourites = ref.watch(favouritesProvider).value ?? const <String>{};
    final voice = ref.watch(settingsProvider.select((s) => s.voice));
    final player = ref.watch(playerProvider);

    final tales = [...catalog.catalog.tales]
      ..sort((a, b) {
        final fa = favourites.contains(a.id) ? 0 : 1;
        final fb = favourites.contains(b.id) ? 0 : 1;
        return fa != fb ? fa - fb : 0;
      });

    return Scaffold(
      appBar: AppBar(
        title: Text(S.appName, style: kidTitleStyle(size: 26, color: Night.accent)),
        actions: [
          IconButton(
            tooltip: S.settingsTitle,
            icon: const Icon(Icons.tune),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (player.active)
            ListTile(
              leading: Icon(player.playing ? Icons.graphic_eq : Icons.pause, color: Night.accent),
              title: Text(player.title, style: kidTitleStyle(size: 20)),
              subtitle: const Text(S.homeNowPlaying),
              onTap: () => context.push('/player'),
            ),
          ListTile(
            leading: const Icon(Icons.waves),
            title: const Text(S.homeJukebox, style: TextStyle(fontSize: 18)),
            subtitle: const Text(S.homeJukeboxSub),
            onTap: () => context.push('/mixer'),
          ),
          const SectionLabel(S.homeTales),
          for (final t in tales)
            Builder(builder: (context) {
              final track = t.track(voice) ?? (t.tracks.isEmpty ? null : t.tracks.first);
              final local = track != null && catalog.resolve(track) != null;
              return ListTile(
                key: ValueKey('tale-${t.id}'),
                title: Text(t.title, style: kidTitleStyle()),
                subtitle: Text(
                  '${S.detailAge(t.age)} · ${local ? S.homeDownloaded : S.homeNotDownloaded}',
                ),
                trailing: favourites.contains(t.id)
                    ? const Icon(Icons.star, color: Night.accent)
                    : null,
                onTap: () => context.push('/tale/${t.id}'),
              );
            }),
        ],
      ),
    );
  }
}
