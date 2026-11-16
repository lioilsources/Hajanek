import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ol1n_telemetry/ol1n_telemetry.dart';

import 'core/form_factor.dart';
import 'core/strings.dart';
import 'core/telemetry.dart';
import 'core/theme.dart';
import 'features/catalog/catalog_controller.dart';
import 'features/catalog/home_screen.dart';
import 'features/catalog/tale_detail_screen.dart';
import 'features/mixer/mixer_screen.dart';
import 'features/player/player_controller.dart';
import 'features/player/player_screen.dart';
import 'features/settings/settings_controller.dart';
import 'features/settings/settings_screen.dart';
import 'features/tv/tv_home_screen.dart';
import 'features/tv/tv_mixer_screen.dart';
import 'features/tv/tv_player_screen.dart';
import 'features/tv/tv_tale_screen.dart';
import 'features/tv/tv_voice_screen.dart';
import 'features/tv/tv_widgets.dart';
import 'features/voice/record_voice_screen.dart';
import 'features/voice/voice_controller.dart';
import 'features/voice/voice_screen.dart';

/// Same paths on phone and TV; a TV has its own screens and no recording.
GoRouter buildRouter([FormFactor formFactor = FormFactor.phone]) {
  final tv = formFactor == FormFactor.tv;
  return GoRouter(
    // Reports kScreenRoutes names only; a path with a tale id never leaves.
    observers: [TelemetryNavigatorObserver(kScreenRoutes)],
    routes: [
      GoRoute(path: '/', builder: (_, _) => tv ? const TvHomeScreen() : const HomeScreen()),
      GoRoute(
        path: '/tale/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return tv ? TvTaleScreen(taleId: id) : TaleDetailScreen(taleId: id);
        },
      ),
      GoRoute(path: '/player', builder: (_, _) => tv ? const TvPlayerScreen() : const PlayerScreen()),
      GoRoute(path: '/mixer', builder: (_, _) => tv ? const TvMixerScreen() : const MixerScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/voice', builder: (_, _) => tv ? const TvVoiceScreen() : const VoiceScreen()),
      if (!tv) GoRoute(path: '/voice/record', builder: (_, _) => const RecordVoiceScreen()),
    ],
  );
}

/// Keeps the screen on; overridden in main() on TV (wakelock_plus).
final wakelockProvider = Provider<void Function(bool on)>((ref) => (_) {});

class HajanekApp extends ConsumerStatefulWidget {
  const HajanekApp({super.key});

  @override
  ConsumerState<HajanekApp> createState() => _HajanekAppState();
}

class _HajanekAppState extends ConsumerState<HajanekApp> {
  late final _tv = ref.read(formFactorProvider) == FormFactor.tv;
  late final _router = buildRouter(ref.read(formFactorProvider));

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

  /// Home shows a hint when the phone has no voice for the language.
  void _reportMissingVoice(AsyncValue<bool?>? _, AsyncValue<bool?> next) {
    if (next.value == false && !ref.read(settingsProvider).czechHintDismissed) {
      Telemetry.errorShown('tts_missing');
    }
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tv) {
      // A TV left on would never sleep; keep it awake only while something
      // plays, so after the tale (or the timer) it can go to standby.
      ref.listen(playerProvider.select((p) => p.playing), (_, playing) => ref.read(wakelockProvider)(playing));
    }
    ref.listen(systemVoiceAvailableProvider, _reportMissingVoice);
    final lang = ref.watch(contentLangProvider);
    ref.listen(contentLangProvider, (_, next) {
      setStringsLang(next);
      ref.read(systemTtsProvider)?.setLang(next);
      ref.read(catalogProvider.notifier).switchLang(next);
    });
    if (stringsLang != lang) setStringsLang(lang);
    return MaterialApp.router(
      // S is a global; a new key rebuilds every screen in the new language.
      key: ValueKey(lang),
      title: appName,
      locale: langLocale(lang),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: buildNightTheme(tv: _tv),
      darkTheme: buildNightTheme(tv: _tv),
      themeMode: ThemeMode.dark,
      routerConfig: _router,
      builder: _tv
          ? (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(Tv.textScale)),
                child: child!,
              )
          : null,
    );
  }
}
