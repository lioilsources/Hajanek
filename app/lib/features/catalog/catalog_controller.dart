import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/content_ref.dart';
import 'catalog_models.dart';
import 'catalog_repository.dart';

enum SyncStatus { idle, checking, upToDate, updated, offline }

class CatalogState {
  const CatalogState({required this.snapshot, this.sync = SyncStatus.idle});

  final CatalogSnapshot snapshot;
  final SyncStatus sync;

  Catalog get catalog => snapshot.catalog;
  ContentRef? resolve(CatalogFile f) => snapshot.local.resolve(f);
  ContentRef? ambientRef(String id) {
    final a = catalog.ambientById(id);
    return a == null ? null : resolve(a);
  }

  CatalogState copyWith({CatalogSnapshot? snapshot, SyncStatus? sync}) =>
      CatalogState(snapshot: snapshot ?? this.snapshot, sync: sync ?? this.sync);
}

/// Overridden in main() with the result of [CatalogRepository.init].
final initialCatalogProvider =
    Provider<CatalogSnapshot>((ref) => throw UnimplementedError('catalog'));

/// Null in tests: no sync, scripts can't be loaded.
final catalogRepositoryProvider = Provider<CatalogRepository?>((ref) => null);

final catalogProvider = NotifierProvider<CatalogController, CatalogState>(CatalogController.new);

class CatalogController extends Notifier<CatalogState> {
  @override
  CatalogState build() => CatalogState(snapshot: ref.read(initialCatalogProvider));

  Future<void> sync() async {
    final repo = ref.read(catalogRepositoryProvider);
    if (repo == null || state.sync == SyncStatus.checking) return;
    state = state.copyWith(sync: SyncStatus.checking);
    try {
      final (result, snap) = await repo.sync(state.snapshot);
      state = state.copyWith(
        snapshot: snap,
        sync: result == SyncResult.updated ? SyncStatus.updated : SyncStatus.upToDate,
      );
    } on Object {
      state = state.copyWith(sync: SyncStatus.offline);
    }
  }

  /// Script text of [f]; null when it isn't available locally.
  Future<String?> loadScript(ScriptFile f) async {
    final repo = ref.read(catalogRepositoryProvider);
    final r = state.resolve(f);
    if (repo == null || r == null) return null;
    return repo.loadText(r);
  }
}
