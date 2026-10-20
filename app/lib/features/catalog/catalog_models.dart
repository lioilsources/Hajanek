// Pure Dart model of catalog.json (docs/CONTRACTS.md §3). No Flutter imports.

class CatalogFormatException implements Exception {
  CatalogFormatException(this.message);
  final String message;
  @override
  String toString() => 'CatalogFormatException: $message';
}

/// The only schema this app understands.
const supportedCatalogSchema = 1;

/// Anything with a path relative to base_url and a content hash.
abstract interface class CatalogFile {
  String get path;
  String get sha256;
  int get bytes;
}

class Voice {
  const Voice({required this.id, required this.label, required this.free});
  final String id;
  final String label;
  final bool free;

  factory Voice.fromJson(Map<String, dynamic> j) => Voice(
        id: _str(j, 'id'),
        label: _str(j, 'label'),
        free: j['free'] as bool? ?? true,
      );
}

class Track implements CatalogFile {
  const Track({
    required this.voice,
    required this.lengthMin,
    required this.path,
    required this.durationS,
    required this.bytes,
    required this.sha256,
  });
  final String voice;
  final int lengthMin;
  @override
  final String path;
  final double durationS;
  @override
  final int bytes;
  @override
  final String sha256;

  factory Track.fromJson(Map<String, dynamic> j) => Track(
        voice: _str(j, 'voice'),
        lengthMin: (j['length_min'] as num).toInt(),
        path: _str(j, 'path'),
        durationS: (j['duration_s'] as num).toDouble(),
        bytes: (j['bytes'] as num).toInt(),
        sha256: _sha(j),
      );
}

class Tale {
  const Tale({
    required this.id,
    required this.title,
    required this.age,
    required this.setting,
    required this.ambient,
    required this.free,
    required this.tracks,
  });
  final String id;
  final String title;
  final String age;
  final String setting;
  final String ambient;
  final bool free;
  final List<Track> tracks;

  Track? track(String voice, {int lengthMin = 10}) {
    for (final t in tracks) {
      if (t.voice == voice && t.lengthMin == lengthMin) return t;
    }
    return null;
  }

  factory Tale.fromJson(Map<String, dynamic> j) => Tale(
        id: _str(j, 'id'),
        title: _str(j, 'title'),
        age: j['age'] as String? ?? '',
        setting: j['setting'] as String? ?? '',
        ambient: j['ambient'] as String? ?? '',
        free: j['free'] as bool? ?? true,
        tracks: [
          for (final t in (j['tracks'] as List? ?? const []))
            Track.fromJson(t as Map<String, dynamic>),
        ],
      );
}

class Ambient implements CatalogFile {
  const Ambient({
    required this.id,
    required this.title,
    required this.path,
    required this.durationS,
    required this.bytes,
    required this.sha256,
    required this.free,
    this.license = '',
    this.source = '',
  });
  final String id;
  final String title;
  @override
  final String path;
  final double durationS;
  @override
  final int bytes;
  @override
  final String sha256;
  final bool free;
  final String license;
  final String source;

  factory Ambient.fromJson(Map<String, dynamic> j) => Ambient(
        id: _str(j, 'id'),
        title: _str(j, 'title'),
        path: _str(j, 'path'),
        durationS: (j['duration_s'] as num).toDouble(),
        bytes: (j['bytes'] as num).toInt(),
        sha256: _sha(j),
        free: j['free'] as bool? ?? true,
        license: j['license'] as String? ?? '',
        source: j['source'] as String? ?? '',
      );
}

class MixLayer {
  const MixLayer({required this.ambient, required this.volume});
  final String ambient;
  final double volume;

  MixLayer copyWith({String? ambient, double? volume}) =>
      MixLayer(ambient: ambient ?? this.ambient, volume: volume ?? this.volume);

  factory MixLayer.fromJson(Map<String, dynamic> j) => MixLayer(
        ambient: _str(j, 'ambient'),
        volume: ((j['volume'] as num?) ?? 0.7).toDouble().clamp(0.0, 1.0),
      );
  Map<String, dynamic> toJson() => {'ambient': ambient, 'volume': volume};

  @override
  bool operator ==(Object other) =>
      other is MixLayer && other.ambient == ambient && other.volume == volume;
  @override
  int get hashCode => Object.hash(ambient, volume);
}

/// Max layers in a mix: 1 main + 2 secondary.
const maxMixLayers = 3;

class MixPreset {
  const MixPreset({
    required this.id,
    required this.title,
    required this.layers,
    this.user = false,
  });
  final String id;
  final String title;
  final List<MixLayer> layers;

  /// True for presets the parent saved (stored in drift, deletable).
  final bool user;

  factory MixPreset.fromJson(Map<String, dynamic> j, {bool user = false}) {
    final layers = [
      for (final l in (j['layers'] as List? ?? const []))
        MixLayer.fromJson(l as Map<String, dynamic>),
    ];
    if (layers.isEmpty || layers.length > maxMixLayers) {
      throw CatalogFormatException('preset ${j['id']}: 1–3 layers required');
    }
    return MixPreset(id: _str(j, 'id'), title: _str(j, 'title'), layers: layers, user: user);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'layers': [for (final l in layers) l.toJson()],
      };
}

class Catalog {
  const Catalog({
    required this.schema,
    required this.version,
    required this.generatedAt,
    required this.baseUrl,
    required this.voices,
    required this.tales,
    required this.ambient,
    required this.presets,
  });
  final int schema;
  final int version;
  final DateTime? generatedAt;
  final String baseUrl;
  final List<Voice> voices;
  final List<Tale> tales;
  final List<Ambient> ambient;
  final List<MixPreset> presets;

  Tale? tale(String id) => _firstWhere(tales, (t) => t.id == id);
  Ambient? ambientById(String id) => _firstWhere(ambient, (a) => a.id == id);
  Voice? voice(String id) => _firstWhere(voices, (v) => v.id == id);

  /// Every downloadable file referenced by this catalog.
  Iterable<CatalogFile> get files sync* {
    yield* ambient;
    for (final t in tales) {
      yield* t.tracks;
    }
  }

  Uri urlFor(String path) => Uri.parse(baseUrl).resolve(path);

  factory Catalog.fromJson(Map<String, dynamic> j) {
    final schema = (j['schema'] as num?)?.toInt();
    if (schema != supportedCatalogSchema) {
      throw CatalogFormatException('unsupported schema $schema');
    }
    final version = j['version'];
    if (version is! num) throw CatalogFormatException('missing version');
    final base = j['base_url'] as String? ?? '';
    return Catalog(
      schema: schema!,
      version: version.toInt(),
      generatedAt: DateTime.tryParse(j['generated_at'] as String? ?? ''),
      baseUrl: base.endsWith('/') || base.isEmpty ? base : '$base/',
      voices: [for (final v in (j['voices'] as List? ?? const [])) Voice.fromJson(v as Map<String, dynamic>)],
      tales: [for (final t in (j['tales'] as List? ?? const [])) Tale.fromJson(t as Map<String, dynamic>)],
      ambient: [for (final a in (j['ambient'] as List? ?? const [])) Ambient.fromJson(a as Map<String, dynamic>)],
      presets: [for (final p in (j['presets'] as List? ?? const [])) MixPreset.fromJson(p as Map<String, dynamic>)],
    );
  }
}

T? _firstWhere<T>(Iterable<T> xs, bool Function(T) test) {
  for (final x in xs) {
    if (test(x)) return x;
  }
  return null;
}

String _str(Map<String, dynamic> j, String key) {
  final v = j[key];
  if (v is! String || v.isEmpty) throw CatalogFormatException('missing "$key"');
  return v;
}

final _hex64 = RegExp(r'^[0-9a-f]{64}$');

String _sha(Map<String, dynamic> j) {
  final v = _str(j, 'sha256').toLowerCase();
  if (!_hex64.hasMatch(v)) throw CatalogFormatException('bad sha256 for ${j['path']}');
  return v;
}
