import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'features/catalog/catalog_controller.dart';
import 'features/catalog/home_screen.dart';
import 'features/catalog/tale_detail_screen.dart';
import 'features/mixer/mixer_screen.dart';
import 'features/player/player_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/voice/record_voice_screen.dart';
import 'features/voice/voice_controller.dart';
import 'features/voice/voice_screen.dart';

GoRouter buildRouter() => GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/tale/:id',
          builder: (_, state) => TaleDetailScreen(taleId: state.pathParameters['id']!),
        ),
        GoRoute(path: '/player', builder: (_, _) => const PlayerScreen()),
        GoRoute(path: '/mixer', builder: (_, _) => const MixerScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(path: '/voice', builder: (_, _) => const VoiceScreen()),
        GoRoute(path: '/voice/record', builder: (_, _) => const RecordVoiceScreen()),
      ],
    );

class HajanekApp extends ConsumerStatefulWidget {
  const HajanekApp({super.key});

  @override
  ConsumerState<HajanekApp> createState() => _HajanekAppState();
}

class _HajanekAppState extends ConsumerState<HajanekApp> {
  final _router = buildRouter();

  @override
  void initState() {
    super.initState();
    // Silent background check; everything works without it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(catalogProvider.notifier).sync();
      ref.read(voiceProvider.notifier).startPolling();
    });
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: S.appName,
        debugShowCheckedModeBanner: false,
        theme: buildNightTheme(),
        darkTheme: buildNightTheme(),
        themeMode: ThemeMode.dark,
        routerConfig: _router,
      );
}
