// content/voice/recording_script.md → what the parent reads aloud.

class RecordingText {
  const RecordingText({required this.consent, required this.lines, required this.tips});

  /// The consent sentence; always read first (CONTRACTS §8).
  final String consent;
  final List<String> lines;
  final List<String> tips;
}

RecordingText parseRecordingScript(String md, {required String name}) {
  var body = md.replaceAll('\r\n', '\n');
  if (body.startsWith('---\n')) {
    final end = body.indexOf('\n---', 4);
    if (end >= 0) body = body.substring(body.indexOf('\n', end + 4) + 1);
  }
  body = body.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  final who = name.trim().isEmpty ? '…' : name.trim();

  final sections = <String, List<String>>{};
  List<String>? cur;
  for (final raw in body.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('## ')) {
      cur = sections.putIfAbsent(line.substring(3).trim(), () => []);
    } else if (line.isNotEmpty && cur != null) {
      cur.add(line.replaceAll('{{jmeno}}', who));
    }
  }
  return RecordingText(
    consent: (sections['souhlas'] ?? const []).join(' '),
    lines: sections['text'] ?? const [],
    tips: [for (final t in sections['pokyny'] ?? const <String>[]) t.replaceFirst(RegExp(r'^-\s*'), '')],
  );
}
