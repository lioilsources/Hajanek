import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/db/database.dart';
import 'core/providers.dart';
import 'features/catalog/catalog_controller.dart';
import 'features/catalog/catalog_repository.dart';
import 'features/player/audio_engine.dart';
import 'features/player/audio_handler.dart';
import 'features/player/player_controller.dart';
import 'features/settings/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();
  final settings = AppSettings.fromValues(await db.readAllValues());

  final repo = CatalogRepository(
    loadBundledCatalog: () => rootBundle.loadString('assets/catalog/catalog.json'),
    listBundledAssets: () async =>
        (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets().toSet(),
    docsDir: getApplicationDocumentsDirectory,
  );
  final snapshot = await repo.init();

  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  HajanekAudioHandler? handler;
  try {
    handler = await AudioService.init(
      builder: HajanekAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.ol1n.hajanek.audio',
        androidNotificationChannelName: 'Přehrávání',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } on Object catch (e) {
    // Playback still works in the foreground without the service.
    debugPrint('AudioService.init failed: $e');
  }

  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      initialSettingsProvider.overrideWithValue(settings),
      initialCatalogProvider.overrideWithValue(snapshot),
      catalogRepositoryProvider.overrideWithValue(repo),
      audioEngineProvider.overrideWithValue(JustAudioEngine()),
      audioHandlerProvider.overrideWithValue(handler),
    ],
    child: const HajanekApp(),
  ));
}
