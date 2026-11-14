import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ol1n_telemetry/ol1n_telemetry.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app.dart';
import 'core/db/database.dart';
import 'core/form_factor.dart';
import 'core/providers.dart';
import 'core/strings.dart';
import 'core/telemetry.dart';
import 'features/catalog/catalog_controller.dart';
import 'features/catalog/catalog_repository.dart';
import 'features/player/audio_engine.dart';
import 'features/player/audio_handler.dart';
import 'features/player/player_controller.dart';
import 'features/player/system_tts.dart';
import 'features/settings/settings_controller.dart';
import 'features/voice/voice_api.dart';
import 'features/voice/voice_controller.dart';

class SecureTokenStore implements TokenStore {
  static const _key = 'hajanek_device_token';
  final _storage = const FlutterSecureStorage();
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  @override
  Future<void> delete() => _storage.delete(key: _key);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final formFactor = await detectFormFactor();
  final db = AppDatabase();
  final values = await db.readAllValues();
  final settings = AppSettings.fromValues(values);
  final lang = settings.lang.isEmpty ? langFor(WidgetsBinding.instance.platformDispatcher.locales) : settings.lang;
  setStringsLang(lang);

  // Anonymous usage statistics (docs/telemetry.md). Without TELEMETRY_KEY
  // and TELEMETRY_HOST this records and sends nothing.
  final supportDir = (await getApplicationSupportDirectory()).path;
  unawaited(Telemetry.init(
    app: kTelemetryApp,
    appVersion: kAppVersion,
    dictionary: hajanekDictionary,
    store: FileTelemetryStore('$supportDir/telemetry'),
    lang: () => stringsLang,
    tester: const bool.fromEnvironment('TESTER_UNLOCK'),
    // Settings or a played tale from before measuring: not a new install.
    hadDataBefore: () async => values.isNotEmpty || await db.hasHistory(),
    common: () => {'form': formFactor == FormFactor.tv ? 'tv' : 'phone'},
    pauseProps: () => {'audio': telemetryAudio},
  ));

  final repo = CatalogRepository(
    loadAsset: rootBundle.loadString,
    listBundledAssets: () async =>
        (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets().toSet(),
    docsDir: getApplicationDocumentsDirectory,
  );
  final snapshot = await repo.init(lang);
  final voicesDir = '$supportDir/voices';

  // Category playback: ambient and speech (system TTS too) keep going with
  // the screen locked; UIBackgroundModes=audio is set in Info.plist.
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  HajanekAudioHandler? handler;
  try {
    handler = await AudioService.init(
      builder: HajanekAudioHandler.new,
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.ol1n.hajanek.audio',
        androidNotificationChannelName: S.playerChannel,
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
      formFactorProvider.overrideWithValue(formFactor),
      if (formFactor == FormFactor.tv)
        wakelockProvider.overrideWithValue((on) => WakelockPlus.toggle(enable: on).catchError(
              (Object e) => debugPrint('wakelock: $e'),
            )),
      databaseProvider.overrideWithValue(db),
      initialSettingsProvider.overrideWithValue(settings),
      initialCatalogProvider.overrideWithValue(snapshot),
      catalogRepositoryProvider.overrideWithValue(repo),
      audioEngineProvider.overrideWithValue(JustAudioEngine()),
      audioHandlerProvider.overrideWithValue(handler),
      systemTtsProvider.overrideWithValue(SystemTtsSource(lang: lang)),
      clipOutputProvider.overrideWithValue(JustAudioClipOutput()),
      voicesDirProvider.overrideWithValue(voicesDir),
      initialVoicesProvider.overrideWithValue(LocalVoice.decodeList(values[parentVoicesKey])),
      if (voiceCloningEnabled) voiceApiProvider.overrideWithValue(VoiceApi(tokens: SecureTokenStore())),
    ],
    child: const HajanekApp(),
  ));
}
