import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajanek/app.dart';
import 'package:hajanek/core/db/database.dart';
import 'package:hajanek/core/providers.dart';
import 'package:hajanek/core/strings.dart';
import 'package:hajanek/features/catalog/catalog_controller.dart';
import 'package:hajanek/features/catalog/catalog_models.dart';
import 'package:hajanek/features/catalog/catalog_repository.dart';
import 'package:hajanek/features/catalog/catalog_sync.dart';
import 'package:hajanek/features/voice/record_voice_screen.dart';
import 'package:hajanek/features/voice/voice_api.dart';
import 'package:hajanek/features/voice/voice_controller.dart';
import 'package:hajanek/features/voice/voice_screen.dart';

CatalogSnapshot bundledSnapshot() {
  final catalog = Catalog.fromJson(
      jsonDecode(File('assets/catalog/catalog.json').readAsStringSync()) as Map<String, dynamic>);
  return CatalogSnapshot(
    catalog: catalog,
    local: LocalContent(
      bundled: {for (final f in catalog.files) f.path: f.sha256},
      blobs: const {},
      blobDir: '/tmp',
    ),
  );
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Widget app({bool? czech, List<LocalVoice> voices = const [], Widget? home}) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialCatalogProvider.overrideWithValue(bundledSnapshot()),
          favouritesProvider.overrideWithValue(const AsyncValue.data({'zlatovlaska'})),
          userPresetsProvider.overrideWithValue(const AsyncValue.data([])),
          czechVoiceAvailableProvider.overrideWith((ref) async => czech),
          initialVoicesProvider.overrideWithValue(voices),
        ],
        child: home == null ? const HajanekApp() : MaterialApp(home: home),
      );

  testWidgets('home lists tales; detail offers the voice and play', (tester) async {
    await tester.pumpWidget(app(czech: true));
    await tester.pump();

    expect(find.text('Hajánek'), findsOneWidget);
    expect(find.text('Jukebox zvuků'), findsOneWidget);
    expect(find.text('Červená Karkulka'), findsOneWidget);
    expect(find.text('Telefon nemá český hlas'), findsNothing);
    // Favourite sorts first.
    final first = tester.getTopLeft(find.text('Zlatovláska')).dy;
    final second = tester.getTopLeft(find.text('Červená Karkulka')).dy;
    expect(first, lessThan(second));
    expect(find.textContaining('10 min'), findsWidgets);

    await tester.tap(find.text('Červená Karkulka'));
    await tester.pumpAndSettle();
    expect(find.text('Hlas telefonu'), findsOneWidget);
    expect(find.text('Spustit'), findsOneWidget);
  });

  testWidgets('home shows the Czech voice hint until dismissed', (tester) async {
    await tester.pumpWidget(app(czech: false));
    await tester.pumpAndSettle();
    expect(find.text('Telefon nemá český hlas'), findsOneWidget);
    await tester.tap(find.text('Rozumím'));
    await tester.pumpAndSettle();
    expect(find.text('Telefon nemá český hlas'), findsNothing);
  });

  testWidgets('voice screen: phone voice, parent voices with status, selection', (tester) async {
    await tester.pumpWidget(app(
      czech: true,
      home: const VoiceScreen(),
      voices: const [
        LocalVoice(id: 'v1', name: 'Máma'),
        LocalVoice(id: 'v2', name: 'Táta', status: VoiceStatus.ready, done: 40, total: 120),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Hlas telefonu'), findsOneWidget);
    expect(find.text('Máma'), findsOneWidget);
    expect(find.text('Hlas se připravuje, bude hotový do rána'), findsOneWidget);
    expect(find.text('Stahuji hlas: 40 z 120 vět'), findsOneWidget);
    expect(find.text('Nahrát můj hlas'), findsOneWidget);

    Finder check(String key) =>
        find.descendant(of: find.byKey(ValueKey(key)), matching: find.byIcon(Icons.check));
    expect(check('voice-system'), findsOneWidget);
    await tester.tap(find.text('Táta'));
    await tester.pumpAndSettle();
    expect(check('voice-system'), findsNothing);
    expect(check('voice-v2'), findsOneWidget);
    expect(find.text(S.voiceMissingClips), findsOneWidget);
  });

  testWidgets('record screen fills the name into the consent sentence', (tester) async {
    await tester.pumpWidget(app(home: const RecordVoiceScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Jsem … a souhlasím'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('rec-name')), 'Jana');
    await tester.pumpAndSettle();
    expect(find.textContaining('Jsem Jana a souhlasím'), findsOneWidget);

    // Recording needs a name and the consent box.
    await tester.scrollUntilVisible(find.text('Nahrávat'), 200, scrollable: find.byType(Scrollable).first);
    final record = find.ancestor(
        of: find.text('Nahrávat'), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
    expect(tester.widget<ButtonStyleButton>(record).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('rec-consent')));
    await tester.pumpAndSettle();
    expect(tester.widget<ButtonStyleButton>(record).onPressed, isNotNull);
  });
}
