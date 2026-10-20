// Pure Dart model of catalog.json (docs/CONTRACTS.md §3). No Flutter imports.

class CatalogFormatException implements Exception {
  CatalogFormatException(this.message);
  final String message;
  @override
  String toString() => 'CatalogFormatException: $message';
}

/// The only schema this app understands.
const supportedCatalogSchema = 2;

/// Anything with a path relative to base_url and a content hash.
abstract interface class CatalogFile {
  String get path;
  String get sha256;
  int get bytes;
}

/// One script text of a tale (a length variant), CONTRACTS §3.
class ScriptFile implements CatalogFile {
  const ScriptFile({
    required this.lengthMin,
    required this.path,
    required this.sha256,
    required this.bytes,
    required this.estDurationS,
  });
  final int lengthMin;
  @override
  final String path;
  @override
  final String sha256;
  @override
  final int bytes;
  final double estDurationS;

  factory ScriptFile.fromJson(Map<String, dynamic> j) => ScriptFile(
        lengthMin: (j['length_min'] as num).toInt(),
        path: _str(j, 'path'),
        sha256: _sha(j),
        bytes: (j['bytes'] as num).toInt(),
        estDurationS: ((j['est_duration_s'] as num?) ?? 0).toDouble(),
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
    required this.scripts,
  });
  final String id;
  final String title;
  final String age;
  final String setting;
  final String ambient;
  final bool free;
  final List<ScriptFile> scripts;

  /// The requested length, else the first variant.
  ScriptFile script({int lengthMin = 10}) => scripts.firstWhere(
        (s) => s.lengthMin == lengthMin,
        orElse: () => scripts.first,
      );

  factory Tale.fromJson(Map<String, dynamic> j) {
    final scripts = [
      for (final s in (j['scripts'] as List? ?? const []))
        ScriptFile.fromJson(s as Map<String, dynamic>),
    ];
    if (scripts.isEmpty) throw CatalogFormatException('tale ${j['id']}: no scripts');
    return Tale(
      id: _str(j, 'id'),
      title: _str(j, 'title'),
      age: j['age'] as String? ?? '',
      setting: j['setting'] as String? ?? '',
      ambient: j['ambient'] as String? ?? '',
      free: j['free'] as bool? ?? true,
      scripts: scripts,
    );
  }
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
    required this.tales,
    required this.ambient,
    required this.presets,
  });
  final int schema;
  final int version;
  final DateTime? generatedAt;
  final String baseUrl;
  final List<Tale> tales;
  final List<Ambient> ambient;
  final List<MixPreset> presets;

  Catalog withoutTales(Set<String> ids) => Catalog(
        schema: schema,
        version: version,
        generatedAt: generatedAt,
        baseUrl: baseUrl,
        tales: [for (final t in tales) if (!ids.contains(t.id)) t],
        ambient: ambient,
        presets: presets,
      );

  Tale? tale(String id) => _firstWhere(tales, (t) => t.id == id);
  Ambient? ambientById(String id) => _firstWhere(ambient, (a) => a.id == id);

  /// Every downloadable file referenced by this catalog.
  Iterable<CatalogFile> get files sync* {
    yield* ambient;
    for (final t in tales) {
      yield* t.scripts;
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
    final c = Catalog(
      schema: schema!,
      version: version.toInt(),
      generatedAt: DateTime.tryParse(j['generated_at'] as String? ?? ''),
      baseUrl: base.endsWith('/') || base.isEmpty ? base : '$base/',
      tales: [for (final t in (j['tales'] as List? ?? const [])) Tale.fromJson(t as Map<String, dynamic>)],
      ambient: [for (final a in (j['ambient'] as List? ?? const [])) Ambient.fromJson(a as Map<String, dynamic>)],
      presets: [for (final p in (j['presets'] as List? ?? const [])) MixPreset.fromJson(p as Map<String, dynamic>)],
    );
    final ambientIds = {for (final a in c.ambient) a.id};
    for (final t in c.tales) {
      if (t.ambient.isNotEmpty && !ambientIds.contains(t.ambient)) {
        throw CatalogFormatException('tale ${t.id}: unknown ambient ${t.ambient}');
      }
    }
    for (final p in c.presets) {
      for (final l in p.layers) {
        if (!ambientIds.contains(l.ambient)) {
          throw CatalogFormatException('preset ${p.id}: unknown ambient ${l.ambient}');
        }
      }
    }
    return c;
  }

  /// Schema of a decoded catalog without parsing the rest.
  static int? schemaOf(Map<String, dynamic> j) => (j['schema'] as num?)?.toInt();
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
