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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

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
          if (czech == false && !hintDismissed)
            CzechVoiceHint(
              onDismiss: () => ref
                  .read(settingsProvider.notifier)
                  .update((s) => s.copyWith(czechHintDismissed: true)),
            ),
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
            ListTile(
              key: ValueKey('tale-${t.id}'),
              title: Text(t.title, style: kidTitleStyle()),
              subtitle: Text('${S.detailAge(t.age)} · ${S.homeMinutes(t.script().estDurationS)}'),
              trailing: favourites.contains(t.id) ? const Icon(Icons.star, color: Night.accent) : null,
              onTap: () => context.push('/tale/${t.id}'),
            ),
        ],
      ),
    );
  }
}
