// Copies every script from ../content/scripts (+ gold/) into assets/scripts/
// and the voice recording text into assets/voice/, and rewrites the `tales`
// of assets/catalog/catalog.json (schema 2) with fresh sha256 / bytes /
// est_duration_s. Ambient and presets are kept.
//
//   cd app && dart run tool/bundle_content.dart [--version N]
//
// Drafts are bundled too; INCLUDE_DRAFTS=false hides them at runtime.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:hajanek/core/script/script.dart';

void main(List<String> args) {
  const catalogPath = 'assets/catalog/catalog.json';
  final catalog = jsonDecode(File(catalogPath).readAsStringSync()) as Map<String, dynamic>;
  final vi = args.indexOf('--version');
  if (vi >= 0) catalog['version'] = int.parse(args[vi + 1]);

  final sources = <String, File>{};
  for (final dir in ['../content/scripts/gold', '../content/scripts']) {
    for (final f in Directory(dir).listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (name.endsWith('.md')) sources[name] = f; // top level wins over gold/
    }
  }

  final out = Directory('assets/scripts');
  if (out.existsSync()) out.deleteSync(recursive: true);
  out.createSync(recursive: true);

  final order = [for (final t in (catalog['tales'] as List? ?? const [])) (t as Map)['id'] as String];
  final tales = <String, Map<String, dynamic>>{};
  for (final name in sources.keys.toList()..sort()) {
    final bytes = sources[name]!.readAsBytesSync();
    final script = parseScript(utf8.decode(bytes));
    final m = script.meta;
    final id = m['id']!;
    final len = int.parse(m['length_min']!);
    if (name != '$id.$len.md') throw StateError('$name: front matter says $id.$len');
    File('${out.path}/$name').writeAsBytesSync(bytes);
    final tale = tales.putIfAbsent(id, () => {
          'id': id,
          'title': m['title'],
          'age': m['age'] ?? '',
          'setting': m['setting'] ?? '',
          'ambient': m['ambient'] ?? '',
          'free': true,
          'scripts': <Map<String, dynamic>>[],
        });
    (tale['scripts'] as List).add({
      'length_min': len,
      'path': 'scripts/$name',
      'sha256': sha256.convert(bytes).toString(),
      'bytes': bytes.length,
      'est_duration_s': script.estimatedSeconds.round(),
    });
    stdout.writeln('$name  ${script.status.padRight(8)}  '
        '${(script.estimatedSeconds / 60).toStringAsFixed(1)} min');
  }

  Directory('assets/voice').createSync(recursive: true);
  File('../content/voice/recording_script.md').copySync('assets/voice/recording_script.md');

  final ids = [...order.where(tales.containsKey), ...tales.keys.where((id) => !order.contains(id))];
  catalog
    ..['schema'] = 2
    ..remove('voices')
    ..['tales'] = [for (final id in ids) tales[id]];
  File(catalogPath).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(catalog)}\n');
}
