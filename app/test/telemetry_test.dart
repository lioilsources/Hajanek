// The checks every app copies from ol1n_telemetry (README "Testovací
// sada"), plus what Hajánek adds: go_router hands the observer the route
// pattern, so screens map and no tale id leaves; playback reports its flow
// and the first tale read to the end is the activation.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hajanek/app.dart';
import 'package:hajanek/core/db/database.dart';
import 'package:hajanek/core/form_factor.dart';
import 'package:hajanek/core/providers.dart';
import 'package:hajanek/core/telemetry.dart';
import 'package:hajanek/features/catalog/catalog_controller.dart';
import 'package:hajanek/features/catalog/catalog_repository.dart';
import 'package:hajanek/features/player/player_controller.dart';
import 'package:hajanek/features/timer/sleep_timer.dart';
import 'package:ol1n_telemetry/ol1n_telemetry.dart';
import 'package:ol1n_telemetry/testing.dart';

import 'home_screen_test.dart' show bundledSnapshot;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('docs/telemetry.md lists exactly the dictionary', () {
    expect(telemetryDocProblems(hajanekDictionary, File('../docs/telemetry.md').readAsStringSync()), isEmpty);
  });

  test('no property is free text', () {
    expect(telemetryDictionaryProblems(hajanekDictionary), isEmpty);
  });

  test('app version matches pubspec.yaml', () {
    expect(telemetryVersionProblems(kAppVersion, File('pubspec.yaml').readAsStringSync()), isEmpty);
  });

  test('the code sends only dictionary events, and every one of them', () {
    expect(telemetryTrackCallProblems(hajanekDictionary), isEmpty);
  });

  test('no key, no network', () async {
    expect(await telemetryNoKeyProblems(hajanekDictionary), isEmpty);
  }, skip: const bool.fromEnvironment('TELEMETRY_DEBUG'));

  test('off means nothing', () async {
    expect(await telemetryOffProblems(hajanekDictionary), isEmpty);
  });

  test('every route of the app, phone and TV, has a screen', () {
    for (final form in FormFactor.values) {
      final router = buildRouter(form);
      final paths = [for (final r in router.configuration.routes) (r as GoRoute).path];
      expect(kScreenRoutes.keys, containsAll(paths), reason: '$form');
      router.dispose();
    }
  });

  test('every bundled tale is in the dictionary', () {
    for (final lang in ['cs', 'en']) {
      for (final t in bundledSnapshot(lang).catalog.tales) {
        expect(telemetryTale(t.id), t.id, reason: '${t.id} ($lang) reports as other');
      }
    }
    expect(telemetryTale('a-new-tale'), 'other');
  });

  test('every sleep timer choice has its own token', () {
    expect({for (final c in SleepTimerOption.choices) telemetryTimer(c)}.length, SleepTimerOption.choices.length);
    expect(telemetryTimer(const SleepTimerOption.minutes(7)), 'other');
  });

  group('with a recording client', () {
    late FakeSink sink;
    var now = DateTime.utc(2026, 11, 14, 19);

    setUp(() async {
      now = DateTime.utc(2026, 11, 14, 19);
      sink = FakeSink();
      Telemetry.resetForTest();
      await Telemetry.init(
        app: kTelemetryApp,
        appVersion: kAppVersion,
        dictionary: hajanekDictionary,
        store: MemoryTelemetryStore(),
        lang: () => 'cs',
        common: () => {'form': 'phone'},
        pauseProps: () => {'audio': telemetryAudio},
        hadDataBefore: () => false,
        sink: sink,
        clock: () => now,
        startTimer: false,
        observeLifecycle: false,
      );
    });
    tearDown(Telemetry.resetForTest);

    // Sent or still queued: session_pause flushes the queue at once.
    List<TelemetryEvent> named(String n) =>
        [for (final e in {...sink.sent, ...Telemetry.debugQueue}) if (e.name == n) e];

    testWidgets('go_router routes map to screens without ids', (tester) async {
      final router = GoRouter(
        observers: [TelemetryNavigatorObserver(kScreenRoutes)],
        routes: [
          for (final path in kScreenRoutes.keys)
            GoRoute(path: path, builder: (_, _) => Scaffold(body: Text(path))),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      router.push('/tale/cervena-karkulka');
      await tester.pumpAndSettle();
      router.push('/voice/record');
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();

      expect([for (final e in named('screen_view')) e.props['screen']], ['home', 'tale', 'voice_record', 'tale']);
      for (final e in Telemetry.debugQueue) {
        expect(e.props.values.whereType<String>().where((v) => v.contains('karkulka')), isEmpty);
      }
    });

    test('a tale: start, pause while it plays, stop by the parent', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final docs = Directory.systemTemp.createTempSync('hajanek_telemetry');
      addTearDown(() => docs.deleteSync(recursive: true));
      final repo = CatalogRepository(
        loadAsset: (a) async => File(a).readAsStringSync(),
        listBundledAssets: () async => {
          for (final f in Directory('assets').listSync(recursive: true))
            if (f is File) f.path,
        },
        docsDir: () async => docs,
      );
      final snapshot = await repo.init('cs');
      final c = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        initialCatalogProvider.overrideWithValue(snapshot),
        catalogRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => now),
      ]);
      addTearDown(c.dispose);
      final player = c.read(playerProvider.notifier);
      final tale = c.read(catalogProvider).catalog.tales.first;

      // The script loads from the bundle; there is no audio in tests.
      final ok = await player.startTale(tale: tale, layers: const [], ritual: false);
      expect(ok, isTrue);
      expect(named('tale_play_start').single.props,
          containsPair('tale', tale.id));
      Telemetry.appPaused();
      expect(named('session_pause').single.props['audio'], 'tale');

      now = now.add(const Duration(minutes: 12));
      await player.stop();
      await Telemetry.flush();
      final end = named('tale_play_end').single.props;
      expect(end['result'], 'stop');
      expect(end['mins'], 12);
      expect(end['voice_done'], isFalse);
      expect(named('activation'), isEmpty);
    });
  });
}
