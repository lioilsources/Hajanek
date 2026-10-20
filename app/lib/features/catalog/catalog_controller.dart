import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio_ref.dart';
import 'catalog_models.dart';
import 'catalog_repository.dart';

enum SyncStatus { idle, checking, upToDate, updated, offline }

class CatalogState {
  const CatalogState({
    required this.snapshot,
    this.sync = SyncStatus.idle,
    this.downloads = const {},
    this.failed = const {},
  });

  final CatalogSnapshot snapshot;
  final SyncStatus sync;

  /// path → progress 0..1 for running downloads.
  final Map<String, double> downloads;

  /// Paths whose last download failed.
  final Set<String> failed;

  Catalog get catalog => snapshot.catalog;
  AudioRef? resolve(CatalogFile f) => snapshot.local.resolve(f);
  AudioRef? ambientRef(String id) {
    final a = catalog.ambientById(id);
    return a == null ? null : resolve(a);
  }

  CatalogState copyWith({
    CatalogSnapshot? snapshot,
    SyncStatus? sync,
    Map<String, double>? downloads,
    Set<String>? failed,
  }) =>
      CatalogState(
        snapshot: snapshot ?? this.snapshot,
        sync: sync ?? this.sync,
        downloads: downloads ?? this.downloads,
        failed: failed ?? this.failed,
      );
}

/// Overridden in main() with the result of [CatalogRepository.init].
final initialCatalogProvider =
    Provider<CatalogSnapshot>((ref) => throw UnimplementedError('catalog'));

/// Null in tests: no sync, no downloads.
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

  Future<void> download(CatalogFile f) async {
    final repo = ref.read(catalogRepositoryProvider);
    if (repo == null || state.downloads.containsKey(f.path)) return;
    state = state.copyWith(
      downloads: {...state.downloads, f.path: 0},
      failed: {...state.failed}..remove(f.path),
    );
    try {
      final local = await repo.download(state.snapshot, f, onProgress: (p) {
        state = state.copyWith(downloads: {...state.downloads, f.path: p});
      });
      state = state.copyWith(
        snapshot: state.snapshot.copyWith(local: local),
        downloads: {...state.downloads}..remove(f.path),
      );
    } on Object {
      state = state.copyWith(
        downloads: {...state.downloads}..remove(f.path),
        failed: {...state.failed, f.path},
      );
    }
  }
}
