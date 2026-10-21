@Tags(['screenshots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:cute_kid_fonts/cute_kid_fonts_testing.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajanek/core/db/database.dart';
import 'package:hajanek/core/providers.dart';
import 'package:hajanek/core/theme.dart';
import 'package:hajanek/features/catalog/catalog_controller.dart';
import 'package:hajanek/features/catalog/catalog_models.dart';
import 'package:hajanek/features/catalog/home_screen.dart';
import 'package:hajanek/features/catalog/tale_detail_screen.dart';
import 'package:hajanek/features/mixer/mixer_screen.dart';
import 'package:hajanek/features/player/player_controller.dart';
import 'package:hajanek/features/player/player_screen.dart';
import 'package:hajanek/features/player/ritual.dart';
import 'package:hajanek/features/player/system_tts.dart' show systemVoiceId;
import 'package:hajanek/features/settings/settings_controller.dart';
import 'package:hajanek/features/settings/settings_screen.dart';
import 'package:hajanek/features/timer/sleep_timer.dart';
import 'package:hajanek/features/voice/record_voice_screen.dart';
import 'package:hajanek/features/voice/voice_api.dart' show VoiceStatus;
import 'package:hajanek/features/voice/voice_controller.dart';
import 'package:hajanek/features/voice/voice_screen.dart';

import 'home_screen_test.dart' show bundledSnapshot;

/// Renders the main screens to PNGs for the store page (olin.now/hajanek):
///
///     SCREENSHOT_DIR=/tmp/shots flutter test test/screenshots_test.dart
///
/// Without SCREENSHOT_DIR every test is skipped, so the normal
/// `flutter test` (and CI) never depends on pixels. The screens are the
/// app's own widgets over the bundled catalog; only the player state and
/// the parent voices are fixtures.
final _dir = Platform.environment['SCREENSHOT_DIR'];

const _phone = Size(390, 844); // iPhone 14/15, rendered @3x
const _ratio = 3.0;

final _shotKey = GlobalKey();

Future<void> _loadFonts() async {
  await loadKidFonts();
  // Body text is the platform font (Roboto on Android); the test
  // environment otherwise draws every glyph as a box.
  final dir = '${Platform.environment['FLUTTER_ROOT']!}/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String f) async => ByteData.sublistView(File('$dir/$f').readAsBytesSync());
  final roboto = FontLoader('Roboto');
  for (final w in ['Regular', 'Medium', 'Bold', 'Italic']) {
    roboto.addFont(read('Roboto-$w.ttf'));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(read('MaterialIcons-Regular.otf'))).load();
}

/// The theme's button text has no family, which a phone resolves to its
/// system font and the test environment to boxes; name the one it would be.
ThemeData _theme() {
  final t = buildNightTheme();
  return t.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: t.filledButtonTheme.style!.copyWith(
        textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 18, fontFamily: 'Roboto')),
      ),
    ),
  );
}

class _FixedPlayer extends PlayerController {
  _FixedPlayer(this.fixed);
  final PlayerState fixed;

  @override
  PlayerState build() => fixed;
}

void main() {
  late AppDatabase db;
  setUpAll(_loadFonts);
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final snapshot = bundledSnapshot();
  final karkulka = snapshot.catalog.tale('cervena-karkulka')!;
  const voices = [
    LocalVoice(id: 'mama', name: 'Máma', status: VoiceStatus.ready, done: 412, total: 412),
    LocalVoice(id: 'tata', name: 'Táta'),
  ];

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget home, {
    PlayerState? player,
    String? voiceId,
    Future<void> Function()? then,
    bool animated = false,
  }) async {
    tester.view.physicalSize = _phone * _ratio;
    tester.view.devicePixelRatio = _ratio;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialCatalogProvider.overrideWithValue(snapshot),
        favouritesProvider.overrideWithValue(const AsyncValue.data({'cervena-karkulka', 'o-smolickovi'})),
        userPresetsProvider.overrideWithValue(const AsyncValue.data([])),
        czechVoiceAvailableProvider.overrideWith((ref) async => true),
        initialVoicesProvider.overrideWithValue(voices),
        initialSettingsProvider.overrideWithValue(AppSettings(voiceId: voiceId ?? systemVoiceId)),
        if (player != null) playerProvider.overrideWith(() => _FixedPlayer(player)),
      ],
      child: RepaintBoundary(
        key: _shotKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _theme(),
          home: home,
        ),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    animated ? await tester.pump(const Duration(seconds: 2)) : await tester.pumpAndSettle();
    if (then != null) await then();

    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: _ratio);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$_dir/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  final skip = _dir == null;

  testWidgets('01 home: tales and the jukebox', skip: skip, (tester) async {
    await shoot(tester, '01-domu', const HomeScreen());
  });

  testWidgets('02 tale detail', skip: skip, (tester) async {
    await shoot(tester, '02-pohadka', TaleDetailScreen(taleId: karkulka.id), voiceId: 'mama');
  });

  testWidgets('03 player mid-tale', skip: skip, (tester) async {
    await shoot(
      tester,
      '03-prehravac',
      const PlayerScreen(),
      animated: true,
      player: PlayerState(
        kind: SessionKind.tale,
        tale: karkulka,
        voiceId: 'mama',
        layers: const [MixLayer(ambient: 'wind', volume: 0.7)],
        balance: 0.6,
        playing: true,
        phase: RitualPhase.voice,
        timer: const SleepTimerOption.endOfTale(),
        progress: 0.42,
        section: 'pribeh',
      ),
    );
  });

  testWidgets('04 jukebox: rain under a lullaby', skip: skip, (tester) async {
    await shoot(
      tester,
      '04-jukebox',
      const MixerScreen(),
      player: const PlayerState(
        kind: SessionKind.mixer,
        playing: true,
        layers: [
          MixLayer(ambient: 'rain', volume: 0.75),
          MixLayer(ambient: 'lullaby-musicbox', volume: 0.5),
        ],
        timer: SleepTimerOption.minutes(30),
        timerRemaining: Duration(minutes: 27, seconds: 41),
      ),
    );
  });

  testWidgets('05 jukebox: nature sounds and lullabies to choose from', skip: skip,
      (tester) async {
    await shoot(
      tester,
      '05-jukebox-zvuky',
      const MixerScreen(),
      player: const PlayerState(layers: [MixLayer(ambient: 'sea', volume: 0.7)]),
      then: () async {
        await tester.tap(find.text('Moře'));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -260));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('06 voices: phone and parents', skip: skip, (tester) async {
    await shoot(tester, '06-hlas', const VoiceScreen(), voiceId: 'mama');
  });

  testWidgets('07 recording a parent voice', skip: skip, (tester) async {
    await shoot(
      tester,
      '07-nahravani',
      const RecordVoiceScreen(),
      then: () async {
        await tester.enterText(find.byKey(const ValueKey('rec-name')), 'Jana');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('08 settings', skip: skip, (tester) async {
    await shoot(tester, '08-nastaveni', const SettingsScreen(), voiceId: 'mama');
  });
}
