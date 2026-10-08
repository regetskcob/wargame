import 'package:flutter/material.dart';
import 'package:flutter_watchos/flutter_watchos.dart';

import '../theme.dart';

/// The page behind every watch menu: the plate colour, a list that the
/// Digital Crown scrolls, and room around the corners and under the clock.
class WatchPage extends StatelessWidget {
  const WatchPage({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return ColoredBox(
      color: BwColors.background,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          12 + padding.left,
          // Under the clock, which watchOS draws over the app.
          WatchStatusBar.heightOf(context) + 4,
          12 + padding.right,
          16 + padding.bottom,
        ),
        children: children,
      ),
    );
  }
}

/// A button the full width of the watch, tall enough for a thumb.
class WatchButton extends StatelessWidget {
  const WatchButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.danger = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? BwColors.danger : BwColors.amber;
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 10),
      ),
    );
    final text = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
      ),
    );
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
        Flexible(child: text),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: primary
          ? FilledButton(onPressed: onPressed, style: style, child: child)
          : OutlinedButton(
              onPressed: onPressed,
              style: style.copyWith(
                foregroundColor: WidgetStatePropertyAll(color),
                side: WidgetStatePropertyAll(BorderSide(color: color)),
              ),
              child: child,
            ),
    );
  }
}

/// A small heading over a block of a menu.
class WatchLabel extends StatelessWidget {
  const WatchLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: BwColors.sand,
      ),
    ),
  );
}
