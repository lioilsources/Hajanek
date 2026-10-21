import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';

/// The only motion in the app: a very dim, slowly breathing circle.
class BreathingCircle extends StatefulWidget {
  const BreathingCircle({super.key, this.size = 220});
  final double size;

  @override
  State<BreathingCircle> createState() => _BreathingCircleState();
}

class _BreathingCircleState extends State<BreathingCircle> with SingleTickerProviderStateMixin {
  // ~6 breaths per minute: 5 s in, 5 s out.
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 5))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _CirclePainter(Curves.easeInOut.transform(_c.value)),
          ),
        ),
      );
}

class _CirclePainter extends CustomPainter {
  _CirclePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 * (0.62 + 0.38 * t);
    canvas.drawCircle(
      size.center(Offset.zero),
      r,
      Paint()..color = Night.accent.withValues(alpha: 0.10 + 0.06 * t),
    );
  }

  @override
  bool shouldRepaint(_CirclePainter old) => old.t != t;
}

/// After [after] without touches, dims the child further; the first tap
/// only wakes the screen (it doesn't hit the buttons underneath).
class InactivityDimmer extends StatefulWidget {
  const InactivityDimmer({
    super.key,
    required this.child,
    this.after = const Duration(seconds: 10),
    this.opacity = 0.75,
  });
  final Widget child;
  final Duration after;
  final double opacity;

  @override
  State<InactivityDimmer> createState() => _InactivityDimmerState();
}

class _InactivityDimmerState extends State<InactivityDimmer> {
  Timer? _timer;
  bool _dim = false;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(widget.after, () {
      if (mounted) setState(() => _dim = true);
    });
  }

  void _wake() {
    if (_dim) setState(() => _dim = false);
    _arm();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _wake(),
        child: Stack(
          children: [
            widget.child,
            if (_dim)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: ColoredBox(color: Colors.black.withValues(alpha: widget.opacity)),
                ),
              ),
          ],
        ),
      );
}

/// Bottom sheet with big rows for picking one value.
Future<T?> showChoiceSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> choices,
  required String Function(T) label,
  T? selected,
  /// Section heading of each choice; a heading is shown where it changes.
  String Function(T)? group,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final (i, c) in choices.indexed) ...[
                if (group != null && (i == 0 || group(choices[i - 1]) != group(c))) SectionLabel(group(c)),
                ListTile(
                  title: Text(label(c), style: const TextStyle(fontSize: 18)),
                  trailing: c == selected ? const Icon(Icons.check, color: Night.accent) : null,
                  onTap: () => Navigator.of(context).pop(c),
                ),
              ],
            ],
          ),
        ),
      ),
    );

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Text(
          text,
          style: const TextStyle(color: Night.textDim, fontSize: 14, letterSpacing: 0.5),
        ),
      );
}
