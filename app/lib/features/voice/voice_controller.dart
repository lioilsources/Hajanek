import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../catalog/catalog_controller.dart';
import '../player/player_controller.dart';
import '../player/system_tts.dart';
import '../settings/settings_controller.dart';
import 'voice_api.dart';

/// A parent's voice as this phone remembers it (works offline).
class LocalVoice {
  const LocalVoice({
    required this.id,
    required this.name,
    this.status = VoiceStatus.pending,
    this.error,
    this.requested = const {},
    this.done = 0,
    this.total = 0,
  });

  final String id;
  final String name;
  final VoiceStatus status;
  final String? error;

  /// tale id → script sha256 a render was requested for.
  final Map<String, String> requested;

  /// Sentences downloaded / sentences the server plans for all tales.
  final int done;
  final int total;

  bool get complete => status == VoiceStatus.ready && total > 0 && done >= total;

  LocalVoice copyWith({
    VoiceStatus? status,
    String? Function()? error,
    Map<String, String>? requested,
    int? done,
    int? total,
  }) =>
      LocalVoice(
        id: id,
        name: name,
        status: status ?? this.status,
        error: error == null ? this.error : error(),
        requested: requested ?? this.requested,
        done: done ?? this.done,
        total: total ?? this.total,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status.name,
        'error': ?error,
        'requested': requested,
        'done': done,
        'total': total,
      };

  factory LocalVoice.fromJson(Map<String, dynamic> j) => LocalVoice(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        status: VoiceStatus.values.asNameMap()[j['status']] ?? VoiceStatus.pending,
        error: j['error'] as String?,
        requested: {
          for (final e in ((j['requested'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}',
        },
        done: (j['done'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
      );

  static List<LocalVoice> decodeList(String? s) {
    if (s == null || s.isEmpty) return const [];
    try {
      return [for (final v in jsonDecode(s) as List) LocalVoice.fromJson(v as Map<String, dynamic>)];
    } on Object {
      return const [];
    }
  }
}

const parentVoicesKey = 'parent_voices';

/// Clips listed in [manifests] that aren't on disk with the right size,
/// one per utterance key (the same sentence in two tales is one clip).
List<(String, ClipInfo)> planClipDownloads(
  Iterable<RenderManifest> manifests,
  Map<String, int> localSizes,
) {
  final out = <(String, ClipInfo)>[];
  final seen = <String>{};
  for (final m in manifests) {
    for (final e in m.clips.entries) {
      if (!seen.add(e.key)) continue;
      final have = localSizes[e.key];
      if (have != null && (e.value.bytes <= 0 || have == e.value.bytes)) continue;
      out.add((e.key, e.value));
    }
  }
  return out;
}

/// (downloaded, planned) sentences over all manifests.
(int, int) clipProgress(Iterable<RenderManifest> manifests, Set<String> localKeys) {
  var done = 0;
  var total = 0;
  for (final m in manifests) {
    total += m.total;
    done += m.clips.keys.where(localKeys.contains).length;
  }
  return (done, total);
}

class VoiceState {
  const VoiceState({this.voices = const [], this.busy = false, this.message});
  final List<LocalVoice> voices;
  final bool busy;

  /// Last calm problem report (network etc.).
  final String? message;

  VoiceState copyWith({List<LocalVoice>? voices, bool? busy, String? Function()? message}) =>
      VoiceState(
        voices: voices ?? this.voices,
        busy: busy ?? this.busy,
        message: message == null ? this.message : message(),
      );
}

/// Overridden in main() with what drift holds under [parentVoicesKey].
final initialVoicesProvider = Provider<List<LocalVoice>>((ref) => const []);

/// Null in tests unless a mock is injected.
final voiceApiProvider = Provider<VoiceApi?>((ref) => null);

/// True / false once flutter_tts has listed voices; null = unknown.
final czechVoiceAvailableProvider = FutureProvider<bool?>((ref) async {
  final tts = ref.watch(systemTtsProvider);
  if (tts == null) return null;
  return await tts.czechVoice() != null;
});

final voiceProvider = NotifierProvider<VoiceController, VoiceState>(VoiceController.new);

class VoiceController extends Notifier<VoiceState> {
  static const pollEvery = Duration(minutes: 2);
  Timer? _poll;
  Future<void>? _inFlight;

  @override
  VoiceState build() {
    ref.onDispose(() => _poll?.cancel());
    return VoiceState(voices: ref.read(initialVoicesProvider));
  }

  VoiceApi? get _api => ref.read(voiceApiProvider);

  /// Polls while some voice is still being prepared or downloaded.
  void startPolling() {
    if (_poll != null || _api == null) return;
    if (state.voices.every((v) => v.complete || v.status == VoiceStatus.failed)) return;
    unawaited(refresh());
    _poll = Timer.periodic(pollEvery, (_) {
      if (state.voices.every((v) => v.complete || v.status == VoiceStatus.failed)) {
        _poll?.cancel();
        _poll = null;
        return;
      }
      unawaited(refresh());
    });
  }

  Future<void> upload({
    required String samplePath,
    required String name,
    required String consentText,
  }) async {
    final api = _api;
    if (api == null) throw VoiceApiException(msgOffline);
    state = state.copyWith(busy: true, message: () => null);
    try {
      final remote = await api.createVoice(samplePath: samplePath, name: name, consentText: consentText);
      final v = LocalVoice(id: remote.id, name: remote.name.isEmpty ? name : remote.name, status: remote.status);
      _save([...state.voices, v]);
      ref.read(settingsProvider.notifier).update((s) => s.copyWith(voiceId: v.id));
      startPolling();
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> delete(String id) async {
    final api = _api;
    if (api == null) throw VoiceApiException(msgOffline);
    state = state.copyWith(busy: true, message: () => null);
    try {
      await api.deleteVoice(id);
      final dir = ref.read(voicesDirProvider);
      if (dir != null) {
        final d = Directory('$dir/$id');
        if (await d.exists()) await d.delete(recursive: true);
      }
      _save([for (final v in state.voices) if (v.id != id) v]);
      if (ref.read(settingsProvider).voiceId == id) {
        ref.read(settingsProvider.notifier).update((s) => s.copyWith(voiceId: systemVoiceId));
      }
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  /// One pass: voice status → render requests → manifests → clip downloads.
  /// A call while a pass runs joins it.
  Future<void> refresh() => _inFlight ??= _refresh().whenComplete(() => _inFlight = null);

  Future<void> _refresh() async {
    final api = _api;
    if (api == null) return;
    String? message;
    for (final v in [...state.voices]) {
      try {
        await _refreshOne(api, v);
      } on _VoiceGone {
        // Deleted while refreshing (or the app is shutting down).
      } on VoiceApiException catch (e) {
        debugPrint('$e');
        message = e.message;
        break;
      }
      if (!ref.mounted) return;
    }
    if (ref.mounted) state = state.copyWith(message: () => message);
  }

  Future<void> _refreshOne(VoiceApi api, LocalVoice v) async {
    RemoteVoice remote;
    try {
      remote = await api.getVoice(v.id);
    } on VoiceApiException catch (e) {
      if (e.status != 404) rethrow;
      remote = RemoteVoice(id: v.id, name: v.name, status: VoiceStatus.failed, error: e.message);
    }
    var cur = _update(v.id, (x) => x.copyWith(status: remote.status, error: () => remote.error));
    if (remote.status != VoiceStatus.ready) return;

    final catalog = ref.read(catalogProvider).catalog;
    final requested = {...cur.requested};
    final manifests = <RenderManifest>[];
    for (final tale in catalog.tales.where((t) => t.free)) {
      final script = tale.script();
      if (requested[tale.id] != script.sha256) {
        await api.requestRender(v.id, tale.id, script.lengthMin);
        requested[tale.id] = script.sha256;
        cur = _update(v.id, (x) => x.copyWith(requested: {...requested}));
      }
      final m = await api.manifest(v.id, tale.id, script.lengthMin);
      if (m != null) manifests.add(m);
    }

    final root = ref.read(voicesDirProvider);
    if (root == null) return;
    final dir = Directory('$root/${v.id}');
    final sizes = await _localSizes(dir);
    var (done, total) = clipProgress(manifests, sizes.keys.toSet());
    _update(v.id, (x) => x.copyWith(done: done, total: total));
    for (final (key, clip) in planClipDownloads(manifests, sizes)) {
      await api.downloadClip(clip, '${dir.path}/$key.m4a');
      sizes[key] = clip.bytes;
      (done, total) = clipProgress(manifests, sizes.keys.toSet());
      _update(v.id, (x) => x.copyWith(done: done, total: total));
    }
  }

  static Future<Map<String, int>> _localSizes(Directory dir) async {
    final out = <String, int>{};
    if (!await dir.exists()) return out;
    await for (final e in dir.list()) {
      final name = e.uri.pathSegments.last;
      if (e is File && name.endsWith('.m4a')) {
        out[name.substring(0, name.length - 4)] = await e.length();
      }
    }
    return out;
  }

  LocalVoice _update(String id, LocalVoice Function(LocalVoice) f) {
    if (!ref.mounted) throw _VoiceGone();
    LocalVoice? out;
    final next = [
      for (final v in state.voices)
        if (v.id == id) out = f(v) else v,
    ];
    if (out == null) throw _VoiceGone();
    _save(next);
    return out;
  }

  void _save(List<LocalVoice> voices) {
    state = state.copyWith(voices: voices);
    ref
        .read(databaseProvider)
        .writeValue(parentVoicesKey, jsonEncode([for (final v in voices) v.toJson()]));
  }
}

class _VoiceGone implements Exception {}
