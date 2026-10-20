import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/catalog/catalog_models.dart';
import 'db/database.dart';

/// Overridden in main() (and in tests).
final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('database'));

final favouritesProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(databaseProvider).watchFavourites(),
);

final userPresetsProvider = StreamProvider<List<MixPreset>>(
  (ref) => ref.watch(databaseProvider).watchUserPresets(),
);

/// Injectable time source for everything with fades and timers.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
