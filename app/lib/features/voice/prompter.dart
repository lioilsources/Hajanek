import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Calm bedtime reading pace: seconds per letter plus a breath after each
/// line. It only moves the highlight; tapping a line resyncs it.
const promptSecondsPerLetter = 0.075;
const promptLinePause = Duration(milliseconds: 700);

final _letter = RegExp(r'\p{L}', unicode: true);

Duration promptLineDuration(String line) =>
    Duration(milliseconds: (_letter.allMatches(line).length * promptSecondsPerLetter * 1000).round()) + promptLinePause;

/// Index of the line being read [elapsed] after line [from] started.
int promptLineAt(List<String> lines, Duration elapsed, {int from = 0}) {
  var end = Duration.zero;
  for (var i = from; i < lines.length; i++) {
    end += promptLineDuration(lines[i]);
    if (elapsed < end) return i;
  }
  return lines.length - 1;
}

/// Text to read aloud, shown like song lyrics: the line being read is bright
/// and kept in the upper third, lines already read fade out.
class Prompter extends StatefulWidget {
  const Prompter({super.key, required this.lines, required this.active, this.onTapLine});

  final List<String> lines;
  final int active;
  final ValueChanged<int>? onTapLine;

  @override
  State<Prompter> createState() => _PrompterState();
}

class _PrompterState extends State<Prompter> {
  late List<GlobalKey> _keys = _newKeys();

  List<GlobalKey> _newKeys() => [for (var i = 0; i < widget.lines.length; i++) GlobalKey()];

  @override
  void didUpdateWidget(Prompter old) {
    super.didUpdateWidget(old);
    if (old.lines.length != widget.lines.length) _keys = _newKeys();
    if (old.active != widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _follow());
    }
  }

  void _follow() {
    final i = widget.active;
    final ctx = i >= 0 && i < _keys.length ? _keys[i].currentContext : null;
    if (ctx == null || !mounted) return;
    Scrollable.ensureVisible(ctx, alignment: 0.3, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        // Room below the last line so it can still move up to the reading spot.
        padding: EdgeInsets.fromLTRB(20, 24, 20, box.maxHeight * 0.7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < widget.lines.length; i++)
              GestureDetector(
                key: _keys[i],
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTapLine == null ? null : () => widget.onTapLine!(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 400),
                    style: TextStyle(
                      fontSize: 26,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: i == widget.active
                          ? Night.textBright
                          : i < widget.active
                          ? Night.textDim.withValues(alpha: 0.5)
                          : Night.textDim,
                    ),
                    child: Text(widget.lines[i]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
