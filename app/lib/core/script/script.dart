// Meditation script parser (docs/CONTRACTS.md §2, §7). Pure Dart; tested
// against docs/testdata/utterances.golden.json like the Go parser in forge.

import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'tone.dart';

/// Sections in their only allowed order.
const scriptSections = ['uvod', 'vstup', 'pribeh', 'dojezd'];

class ScriptFormatException implements Exception {
  ScriptFormatException(this.message);
  final String message;
  @override
  String toString() => 'ScriptFormatException: $message';
}

sealed class ScriptItem {
  const ScriptItem();
}

class Utterance extends ScriptItem {
  const Utterance({
    required this.section,
    required this.tone,
    required this.text,
    required this.canonicalText,
    required this.indexInSection,
    required this.sectionSize,
  });

  final String section;
  final Tone tone;

  /// What the system voice reads (the child's vocative filled in, if set).
  final String text;

  /// Text with `{{osloveni|fallback}}` → fallback; the basis of [keyFor].
  final String canonicalText;

  /// Position among the utterances of [section] (drives the dojezd ramp).
  final int indexInSection;
  final int sectionSize;

  String keyFor(String voiceId) => utteranceKey(voiceId, tone, canonicalText);
}

class ScriptPause extends ScriptItem {
  const ScriptPause(this.seconds);
  final double seconds;
  Duration get duration => Duration(microseconds: (seconds * 1e6).round());
}

class Script {
  const Script({required this.meta, required this.items});

  /// Flat `key: value` pairs of the front matter (lists stay raw strings).
  final Map<String, String> meta;
  final List<ScriptItem> items;

  String get status => meta['status'] ?? '';
  bool get isDraft => status == 'draft';

  Iterable<Utterance> get utterances => items.whereType<Utterance>();

  /// CONTRACTS §3: 95 words per minute at normal speed plus pauses.
  double get estimatedSeconds {
    var words = 0;
    var pauses = 0.0;
    for (final i in items) {
      switch (i) {
        case Utterance(:final text):
          words += text.split(' ').where((w) => w.isNotEmpty).length;
        case ScriptPause(:final seconds):
          pauses += seconds;
      }
    }
    return words / 95 * 60 + pauses;
  }
}

/// hex(sha256(utf8(voice_id + 0x1f + tone + 0x1f + text))), CONTRACTS §7.
String utteranceKey(String voiceId, Tone tone, String text) =>
    crypto.sha256.convert(utf8.encode('$voiceId\x1f${tone.name}\x1f$text')).toString();

/// Trim, collapse inner whitespace runs to one space, Unicode NFC.
String normalizeUtterance(String s) => unorm.nfc(s.trim().replaceAll(RegExp(r'\s+'), ' '));

final _comment = RegExp(r'<!--.*?-->', dotAll: true);
final _pause = RegExp(r'^\[pause\s+(\d+(?:\.\d+)?)s\]$');
final _toneMark = RegExp(r'^\[(soft|slow|whisper)\]\s*');
final _osloveni = RegExp(r'\{\{\s*osloveni\s*\|([^}]*)\}\}');

/// Parses a script. [vocative] is the child's name in the 5th case
/// (“Aničko”); empty means the fallback after `|` is spoken.
Script parseScript(String source, {String vocative = ''}) {
  var src = source.replaceAll('\r\n', '\n');
  if (src.startsWith('﻿')) src = src.substring(1);

  final meta = <String, String>{};
  var body = src;
  if (src.startsWith('---\n')) {
    final end = src.indexOf('\n---', 4);
    if (end < 0) throw ScriptFormatException('unterminated front matter');
    for (final line in src.substring(4, end).split('\n')) {
      final c = line.indexOf(':');
      if (c <= 0 || line.startsWith(' ')) continue;
      var v = line.substring(c + 1);
      final hash = v.indexOf(' #');
      if (hash >= 0) v = v.substring(0, hash);
      meta[line.substring(0, c).trim()] = v.trim();
    }
    final nl = src.indexOf('\n', end + 4);
    body = nl < 0 ? '' : src.substring(nl + 1);
  }
  body = body.replaceAll(_comment, '');

  final name = vocative.trim();
  final raw = <({String section, Tone tone, String text, String canonical})>[];
  final items = <Object>[]; // index into raw (int) or ScriptPause
  String? section;
  var tone = Tone.soft;
  var sectionIdx = -1;

  for (final rawLine in body.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('## ')) {
      final s = line.substring(3).trim();
      final idx = scriptSections.indexOf(s);
      if (idx < 0) throw ScriptFormatException('unknown section "$s"');
      if (idx <= sectionIdx) throw ScriptFormatException('section "$s" out of order');
      sectionIdx = idx;
      section = s;
      tone = Tone.soft;
      continue;
    }
    if (section == null) continue;

    final p = _pause.firstMatch(line);
    if (p != null) {
      items.add(ScriptPause(double.parse(p.group(1)!)));
      continue;
    }

    var text = line;
    final t = _toneMark.firstMatch(text);
    if (t != null) {
      tone = Tone.values.byName(t.group(1)!);
      text = text.substring(t.end);
    }
    if (_osloveni.hasMatch(text) && section != 'uvod' && section != 'dojezd') {
      throw ScriptFormatException('osloveni outside uvod/dojezd');
    }
    final canonical = normalizeUtterance(text.replaceAllMapped(_osloveni, (m) => m.group(1)!.trim()));
    if (canonical.isEmpty) continue;
    final spoken = name.isEmpty
        ? canonical
        : normalizeUtterance(text.replaceAllMapped(_osloveni, (_) => name));
    items.add(raw.length);
    raw.add((section: section, tone: tone, text: spoken, canonical: canonical));
  }

  final sizes = <String, int>{};
  for (final r in raw) {
    sizes[r.section] = (sizes[r.section] ?? 0) + 1;
  }
  final seen = <String, int>{};
  return Script(
    meta: meta,
    items: [
      for (final i in items)
        if (i is ScriptPause)
          i
        else
          () {
            final r = raw[i as int];
            final n = seen[r.section] ?? 0;
            seen[r.section] = n + 1;
            return Utterance(
              section: r.section,
              tone: r.tone,
              text: r.text,
              canonicalText: r.canonical,
              indexInSection: n,
              sectionSize: sizes[r.section]!,
            );
          }(),
    ],
  );
}
