// Pure sync planning + file resolution. Downloaded files are stored
// content-addressed as `blobs/{sha256}{ext}`, so a new catalog never overwrites
// a file the current one points at; the swap is just renaming catalog.json.

import '../../core/audio_ref.dart';
import 'catalog_models.dart';

/// Single place mapping a catalog audio path to the file actually played on
/// this platform. Identity today (Ogg Opus everywhere). If iOS can't play
/// Ogg Opus, swap the extension here (e.g. `.opus` → `.m4a` on iOS); the
/// catalog would then also need per-variant sha256/bytes (contract change).
String platformAudioPath(String path) => path;

/// Snapshot of what is playable locally.
class LocalContent {
  const LocalContent({
    required this.bundled,
    required this.blobs,
    required this.blobDir,
  });

  /// path → sha256 for files present in the app bundle (`assets/{path}`).
  final Map<String, String> bundled;

  /// sha256 of verified files in [blobDir].
  final Set<String> blobs;
  final String blobDir;

  LocalContent withBlob(String sha) =>
      LocalContent(bundled: bundled, blobs: {...blobs, sha}, blobDir: blobDir);

  LocalContent withBlobs(Set<String> shas) =>
      LocalContent(bundled: bundled, blobs: shas, blobDir: blobDir);

  /// Exact local copy of [f] (downloaded or bundled with matching hash).
  bool hasExact(CatalogFile f) => blobs.contains(f.sha256) || bundled[f.path] == f.sha256;

  /// Exact match first; then a stale bundled file at the same path
  /// (an older loop beats silence); null = needs download.
  AudioRef? resolve(CatalogFile f) {
    if (blobs.contains(f.sha256)) return FileRef(blobPath(blobDir, f));
    if (bundled[f.path] == f.sha256) return AssetRef('assets/${platformAudioPath(f.path)}');
    if (bundled.containsKey(f.path)) return AssetRef('assets/${platformAudioPath(f.path)}');
    return null;
  }
}

String blobName(CatalogFile f) {
  final path = platformAudioPath(f.path);
  final dot = path.lastIndexOf('.');
  final ext = dot >= 0 && dot > path.lastIndexOf('/') ? path.substring(dot) : '';
  return '${f.sha256}$ext';
}

String blobPath(String dir, CatalogFile f) => '$dir/${blobName(f)}';

class SyncPlan {
  const SyncPlan({required this.apply, required this.downloads, required this.garbage});
  const SyncPlan.upToDate()
      : apply = false,
        downloads = const [],
        garbage = const {};

  /// Whether the remote catalog should replace the current one.
  final bool apply;

  /// Files to fetch before swapping.
  final List<CatalogFile> downloads;

  /// Blob hashes no longer referenced after the swap (safe to delete).
  final Set<String> garbage;

  int get downloadBytes => downloads.fold(0, (s, f) => s + f.bytes);
}

/// Decide what to download when [remote] is offered while [current] is active.
///
/// - Ambient loops are always kept local (they're small and needed offline).
/// - Tale tracks are fetched only if the parent had already downloaded the
///   previous version of that track; new tracks stay on-demand.
SyncPlan planSync({
  required Catalog current,
  required Catalog remote,
  required LocalContent local,
}) {
  if (remote.schema != supportedCatalogSchema || remote.version <= current.version) {
    return const SyncPlan.upToDate();
  }

  final downloads = <CatalogFile>[];
  final seen = <String>{};
  void want(CatalogFile f) {
    if (!local.hasExact(f) && seen.add(f.sha256)) downloads.add(f);
  }

  for (final a in remote.ambient) {
    want(a);
  }

  final oldTracks = {
    for (final t in current.tales)
      for (final tr in t.tracks) tr.path: tr,
  };
  for (final t in remote.tales) {
    for (final tr in t.tracks) {
      if (local.hasExact(tr)) continue;
      final old = oldTracks[tr.path];
      if (old != null && local.blobs.contains(old.sha256)) want(tr);
    }
  }

  final referenced = {for (final f in remote.files) f.sha256};
  final garbage = local.blobs.difference(referenced);
  return SyncPlan(apply: true, downloads: downloads, garbage: garbage);
}
