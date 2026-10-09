import 'package:flutter/material.dart';

/// An outlined button with just an icon, as tall as the text buttons next to
/// it, so a secondary action fits on the same row. The tooltip doubles as the
/// label for screen readers.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          minimumSize: const Size(48, 52),
        ),
        child: Icon(icon, semanticLabel: tooltip),
      ),
    );
  }
}
