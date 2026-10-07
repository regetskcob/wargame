import 'package:flutter/material.dart';

import '../../theme.dart';

/// Options laid out as wrapping, beveled chips. Unlike a segmented button the
/// labels may sit on several lines on a narrow screen without breaking words.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.allowNone = false,
    super.key,
  });

  /// Value and label per option, with an optional colour for the label.
  final List<(T, String, Color?)> options;
  final T? selected;
  final ValueChanged<T?> onSelected;

  /// Tapping the selected option clears the choice.
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label, color) in options)
          _chip(value, label, color, value == selected),
      ],
    );
  }

  Widget _chip(T value, String label, Color? color, bool on) {
    return InkWell(
      onTap: () => onSelected(on && allowNone ? null : value),
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: ShapeDecoration(
          color: on ? const Color(0x33FFB300) : const Color(0x44000000),
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(
              color: on ? BwColors.amber : BwColors.oliveLight,
              width: on ? 2 : 1.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: color ?? (on ? BwColors.amber : BwColors.text),
          ),
        ),
      ),
    );
  }
}
