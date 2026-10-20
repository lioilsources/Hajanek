import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajanek/app.dart';
import 'package:hajanek/core/providers.dart';
import 'package:hajanek/features/catalog/catalog_controller.dart';
import 'package:hajanek/features/catalog/catalog_models.dart';
import 'package:hajanek/features/catalog/catalog_repository.dart';
import 'package:hajanek/features/catalog/catalog_sync.dart';

void main() {
  testWidgets('home lists tales and the jukebox entry', (tester) async {
    final catalog = Catalog.fromJson(
        jsonDecode(File('assets/catalog/catalog.json').readAsStringSync()) as Map<String, dynamic>);
    final snapshot = CatalogSnapshot(
      catalog: catalog,
      local: LocalContent(
        bundled: {
          for (final a in catalog.ambient) a.path: a.sha256,
          'audio/cervena-karkulka/mama/10.opus':
              catalog.tale('cervena-karkulka')!.track('mama')!.sha256,
        },
        blobs: const {},
        blobDir: '/tmp',
      ),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        initialCatalogProvider.overrideWithValue(snapshot),
        favouritesProvider.overrideWithValue(const AsyncValue.data({'zlatovlaska'})),
        userPresetsProvider.overrideWithValue(const AsyncValue.data([])),
      ],
      child: const HajanekApp(),
    ));
    await tester.pump();

    expect(find.text('Hajánek'), findsOneWidget);
    expect(find.text('Jukebox zvuků'), findsOneWidget);
    expect(find.text('Červená Karkulka'), findsOneWidget);
    // Favourite sorts first.
    final first = tester.getTopLeft(find.text('Zlatovláska')).dy;
    final second = tester.getTopLeft(find.text('Červená Karkulka')).dy;
    expect(first, lessThan(second));
    expect(find.textContaining('staženo'), findsWidgets);

    await tester.tap(find.text('Červená Karkulka'));
    await tester.pumpAndSettle();
    expect(find.text('Měkký'), findsOneWidget);
    expect(find.text('Hluboký'), findsOneWidget);
    expect(find.text('Spustit'), findsOneWidget);
  });
}
