import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// TV sizes. A 1080p TV is 960×540 logical pixels; text is read from 3 m.
/// All text on TV is scaled by [textScale] on top (shared screens like
/// settings and the choice sheet get it too).
abstract final class Tv {
  static const textScale = 1.25;
  static const gutter = 48.0;
  static const gap = 20.0;
  static const text = 20.0;
  static const textSmall = 18.0;
  static const title = 28.0;
  static const kidTitle = 34.0;
}

/// A remote-friendly button: unmistakable focus (border + slight zoom),
/// select/enter activates. Everything on a TV screen that does something is one.
class TvButton extends StatefulWidget {
  const TvButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.autofocus = false,
    this.focusNode,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    this.filled = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool autofocus;
  final FocusNode? focusNode;
  final EdgeInsets padding;

  /// The screen's main action (accent background).
  final bool filled;

  /// Icon + label, the common case.
  factory TvButton.icon({
    Key? key,
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    bool autofocus = false,
    FocusNode? focusNode,
    bool filled = false,
  }) =>
      TvButton(
        key: key,
        onPressed: onPressed,
        autofocus: autofocus,
        focusNode: focusNode,
        filled: filled,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 12),
            Flexible(child: Text(label, style: const TextStyle(fontSize: Tv.text))),
          ],
        ),
      );

  @override
  State<TvButton> createState() => _TvButtonState();
}

class _TvButtonState extends State<TvButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final bg = widget.filled ? Night.accentDim : (_focused ? Night.surfaceHigh : Night.surface);
    return AnimatedScale(
      scale: _focused ? 1.05 : 1,
      duration: const Duration(milliseconds: 120),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          autofocus: widget.autofocus,
          focusNode: widget.focusNode,
          canRequestFocus: enabled,
          onTap: widget.onPressed,
          onFocusChange: (f) => setState(() => _focused = f),
          focusColor: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: widget.padding,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _focused ? Night.accent : Colors.transparent, width: 3),
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: enabled ? Night.text : Night.textDim),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: enabled ? Night.text : Night.textDim),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Screen frame: title row on top, content below, TV gutters.
class TvPage extends StatelessWidget {
  const TvPage({super.key, required this.title, required this.child, this.actions = const []});
  final Widget title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.fromLTRB(Tv.gutter, 32, Tv.gutter, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: title),
                  for (final a in actions) ...[const SizedBox(width: 16), a],
                ],
              ),
              const SizedBox(height: 24),
              Expanded(child: child),
            ],
          ),
        ),
      );
}
