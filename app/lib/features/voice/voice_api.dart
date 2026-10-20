// Client for hajanek-api (docs/CONTRACTS.md §6, §8). The app talks to this
// one public endpoint only, with an anonymous device token.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const defaultApiUrl = String.fromEnvironment('API_URL', defaultValue: 'https://hajanek-api.ol1n.com');

/// Calm Czech message for the parent; [detail] is for logs.
class VoiceApiException implements Exception {
  VoiceApiException(this.message, {this.detail, this.status});
  final String message;
  final String? detail;
  final int? status;
  @override
  String toString() => 'VoiceApiException($status): $message${detail == null ? '' : ' — $detail'}';
}

const msgOffline = 'Teď se nepodařilo spojit se serverem. Zkusíme to znovu později.';
const msgServer = 'Server teď neodpovídá, jak má. Zkusíme to znovu později.';

/// Where the device token lives (flutter_secure_storage in the app).
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class MemoryTokenStore implements TokenStore {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String t) async => token = t;
  @override
  Future<void> delete() async => token = null;
}

enum VoiceStatus { pending, ready, failed, deleting, unknown }

class RemoteVoice {
  const RemoteVoice({required this.id, required this.name, required this.status, this.error});
  final String id;
  final String name;
  final VoiceStatus status;
  final String? error;

  factory RemoteVoice.fromJson(Map<String, dynamic> j) {
    // Accept both `{voice: {...}}` and the bare object.
    final v = j['voice'] is Map<String, dynamic> ? j['voice'] as Map<String, dynamic> : j;
    return RemoteVoice(
      id: v['id'] as String,
      name: v['name'] as String? ?? '',
      status: VoiceStatus.values.asNameMap()[v['status']] ?? VoiceStatus.unknown,
      error: v['error'] as String?,
    );
  }
}

class ClipInfo {
  const ClipInfo({required this.url, required this.bytes, this.durationS = 0});
  final String url;
  final int bytes;
  final double durationS;
}

/// `GET /v1/voices/{id}/renders/{tale}/{length}`.
class RenderManifest {
  const RenderManifest({
    required this.status,
    required this.scriptSha256,
    required this.done,
    required this.total,
    required this.clips,
  });
  final String status;
  final String scriptSha256;
  final int done;
  final int total;

  /// utterance_key → clip.
  final Map<String, ClipInfo> clips;

  factory RenderManifest.fromJson(Map<String, dynamic> j) {
    final r = j['render'] is Map<String, dynamic> ? j['render'] as Map<String, dynamic> : j;
    return RenderManifest(
      status: r['status'] as String? ?? '',
      scriptSha256: r['script_sha256'] as String? ?? '',
      done: (r['done'] as num?)?.toInt() ?? 0,
      total: (r['total'] as num?)?.toInt() ?? 0,
      clips: {
        for (final e in ((r['clips'] as Map?) ?? const {}).entries)
          '${e.key}': ClipInfo(
            url: (e.value as Map)['url'] as String,
            bytes: ((e.value as Map)['bytes'] as num?)?.toInt() ?? 0,
            durationS: ((e.value as Map)['duration_s'] as num?)?.toDouble() ?? 0,
          ),
      },
    );
  }
}

class VoiceApi {
  VoiceApi({required this.tokens, http.Client? client, Uri? baseUrl})
      : client = client ?? http.Client(),
        baseUrl = baseUrl ?? Uri.parse(defaultApiUrl);

  final TokenStore tokens;
  final http.Client client;
  final Uri baseUrl;
  static const _timeout = Duration(seconds: 30);

  Uri url(String path) => baseUrl.resolve(path);

  /// Registers this device once (`POST /v1/devices`) and keeps the token.
  Future<String> ensureDevice() async {
    final existing = await tokens.read();
    if (existing != null && existing.isNotEmpty) return existing;
    final resp = await _send(() => client.post(url('/v1/devices')));
    final token = (_json(resp) as Map<String, dynamic>)['token'] as String?;
    if (token == null || token.isEmpty) throw VoiceApiException(msgServer, detail: 'no token');
    await tokens.write(token);
    return token;
  }

  Future<RemoteVoice> createVoice({
    required String samplePath,
    required String name,
    required String consentText,
  }) async {
    final token = await ensureDevice();
    final resp = await _send(() async {
      final req = http.MultipartRequest('POST', url('/v1/voices'))
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['name'] = name
        ..fields['consent'] = 'true'
        ..fields['consent_text'] = consentText
        ..files.add(await http.MultipartFile.fromPath('sample', samplePath));
      return http.Response.fromStream(await client.send(req));
    }, timeout: const Duration(minutes: 2));
    return RemoteVoice.fromJson(_json(resp) as Map<String, dynamic>);
  }

  Future<RemoteVoice> getVoice(String id) async =>
      RemoteVoice.fromJson(_json(await _authed('GET', '/v1/voices/$id')) as Map<String, dynamic>);

  /// Deleting a voice that is already gone counts as success.
  Future<void> deleteVoice(String id) async {
    try {
      await _authed('DELETE', '/v1/voices/$id');
    } on VoiceApiException catch (e) {
      if (e.status != 404) rethrow;
    }
  }

  /// Idempotent on the server.
  Future<void> requestRender(String voiceId, String tale, int lengthMin) => _authed(
        'POST',
        '/v1/voices/$voiceId/renders',
        body: {'tale': tale, 'length_min': lengthMin},
      );

  /// Null while the server knows no render for this tale yet.
  Future<RenderManifest?> manifest(String voiceId, String tale, int lengthMin) async {
    try {
      final r = await _authed('GET', '/v1/voices/$voiceId/renders/$tale/$lengthMin');
      return RenderManifest.fromJson(_json(r) as Map<String, dynamic>);
    } on VoiceApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// Streams a clip to [dest] via `dest.part` + rename. No sha256 in the
  /// manifest, so the byte length is the integrity check.
  Future<void> downloadClip(ClipInfo clip, String dest) async {
    final token = await ensureDevice();
    final part = File('$dest.part');
    await part.parent.create(recursive: true);
    try {
      final req = http.Request('GET', url(clip.url))..headers['Authorization'] = 'Bearer $token';
      final resp = await client.send(req).timeout(_timeout);
      if (resp.statusCode != 200) {
        await resp.stream.drain<void>();
        throw VoiceApiException(msgServer, status: resp.statusCode, detail: 'clip ${clip.url}');
      }
      final sink = part.openWrite();
      try {
        await resp.stream.pipe(sink);
      } finally {
        await sink.close();
      }
      final len = await part.length();
      if (clip.bytes > 0 && len != clip.bytes) {
        throw VoiceApiException(msgServer, detail: 'clip ${clip.url}: $len != ${clip.bytes} bytes');
      }
      await part.rename(dest);
    } on SocketException catch (e) {
      throw VoiceApiException(msgOffline, detail: '$e');
    } on TimeoutException catch (e) {
      throw VoiceApiException(msgOffline, detail: '$e');
    } on http.ClientException catch (e) {
      throw VoiceApiException(msgOffline, detail: '$e');
    } finally {
      if (await part.exists()) await part.delete();
    }
  }

  Future<http.Response> _authed(String method, String path, {Object? body}) async {
    final token = await ensureDevice();
    final resp = await _send(() {
      final req = http.Request(method, url(path))..headers['Authorization'] = 'Bearer $token';
      if (body != null) {
        req
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode(body);
      }
      return client.send(req).then(http.Response.fromStream);
    });
    return resp;
  }

  Future<http.Response> _send(Future<http.Response> Function() call, {Duration timeout = _timeout}) async {
    final http.Response resp;
    try {
      resp = await call().timeout(timeout);
    } on SocketException catch (e) {
      throw VoiceApiException(msgOffline, detail: '$e');
    } on TimeoutException catch (e) {
      throw VoiceApiException(msgOffline, detail: '$e');
    } on http.ClientException catch (e) {
      throw VoiceApiException(msgOffline, detail: '$e');
    }
    if (resp.statusCode == 401) {
      // The server forgot this device (e.g. it was deleted); start over.
      await tokens.delete();
    }
    if (resp.statusCode >= 300) {
      throw VoiceApiException(_messageFor(resp.statusCode),
          status: resp.statusCode, detail: utf8.decode(resp.bodyBytes, allowMalformed: true));
    }
    return resp;
  }

  static String _messageFor(int status) => switch (status) {
        401 || 403 => 'Tento telefon server nezná. Zkus to prosím znovu.',
        404 => 'Hlas na serveru už není.',
        413 => 'Nahrávka je moc dlouhá. Stačí 5 až 30 sekund.',
        422 || 400 => 'Server nahrávku nepřijal. Zkus ji prosím nahrát znovu.',
        429 => 'Teď je toho na serveru moc. Zkus to prosím za chvíli.',
        _ => msgServer,
      };

  Object? _json(http.Response r) {
    try {
      return jsonDecode(utf8.decode(r.bodyBytes));
    } on FormatException catch (e) {
      throw VoiceApiException(msgServer, detail: '$e');
    }
  }
}
