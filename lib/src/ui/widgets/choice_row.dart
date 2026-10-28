import 'dart:math';

import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../theme.dart';

/// Options laid out as wrapping chips. Unlike a segmented button the
/// labels may sit on several lines on a narrow screen without breaking words.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.allowNone = false,
    this.expand = false,
    this.balance = false,
    this.minHeight = HzSize.touch,
    super.key,
  });

  /// Value and label per option, with an optional colour for the label.
  final List<(T, String, Color?)> options;
  final T? selected;
  final ValueChanged<T?> onSelected;

  /// Tapping the selected option clears the choice.
  final bool allowNone;

  /// Share the full width in equal parts on one row instead of wrapping.
  final bool expand;

  /// Rows of nearly equal length once the options no longer fit on one,
  /// instead of a last one alone on its line. Not inside intrinsic sizing,
  /// which cannot measure the width first.
  final bool balance;

  final double minHeight;

  @override
  Widget build(BuildContext context) {
    if (expand) {
      return Row(
        children: [
          for (final (i, (value, label, color)) in options.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _chip(value, label, color, value == selected)),
          ],
        ],
      );
    }
    final wrap = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label, color) in options)
          _chip(value, label, color, value == selected),
      ],
    );
    if (!balance) {
      return wrap;
    }
    // What fits on one line stays a row of chips. Otherwise the options go
    // into rows of nearly equal length: a plain wrap left the last one alone
    // on its line (STADT under three terrains).
    return LayoutBuilder(
      builder: (context, box) {
        final rows = _rowsFor(context, box.maxWidth);
        if (rows == null) {
          return wrap;
        }
        final perRow = (options.length / rows).ceil();
        return Column(
          children: [
            for (var start = 0; start < options.length; start += perRow) ...[
              if (start > 0) const SizedBox(height: 8),
              Row(
                children: [
                  for (
                    var i = start;
                    i < min(start + perRow, options.length);
                    i++
                  ) ...[
                    if (i > start) const SizedBox(width: 8),
                    Expanded(
                      child: _chip(
                        options[i].$1,
                        options[i].$2,
                        options[i].$3,
                        options[i].$1 == selected,
                        fill: true,
                      ),
                    ),
                  ],
                  // A shorter last row keeps the width of the others' chips.
                  for (
                    var i = min(start + perRow, options.length);
                    i < start + perRow;
                    i++
                  ) ...[
                    const SizedBox(width: 8),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  /// How many even rows the options need in [width], null when they fit on
  /// one.
  int? _rowsFor(BuildContext context, double width) {
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    final widths = [
      for (final (_, label, _) in options)
        () {
          painter
            ..text = TextSpan(text: label, style: _style(null, false))
            ..layout();
          return painter.width + 2 * (_padding + HzLine.hairline);
        }(),
    ];
    painter.dispose();
    bool fits(int rows) {
      final perRow = (widths.length / rows).ceil();
      for (var start = 0; start < widths.length; start += perRow) {
        final row = widths.sublist(start, min(start + perRow, widths.length));
        // Equal parts: the widest chip sets the width of all of them.
        if (row.reduce(max) * perRow + 8 * (perRow - 1) > width) {
          return false;
        }
      }
      return true;
    }

    if (widths.fold(0.0, (a, b) => a + b) + 8 * (widths.length - 1) <= width) {
      return null;
    }
    for (var rows = 2; rows < widths.length; rows++) {
      if (fits(rows)) {
        return rows;
      }
    }
    return null;
  }

  static const _padding = HzSpace.s12;

  TextStyle _style(Color? color, bool on) => GameType.label.copyWith(
    fontWeight: on ? FontWeight.w600 : FontWeight.w500,
    color: color ?? GameColors.text,
  );

  Widget _chip(
    T value,
    String label,
    Color? color,
    bool on, {
    bool fill = false,
  }) {
    final centred = expand || fill;
    // Horizont's segment: every option in the outline, the chosen one as
    // Horizont's selection (tint and the 2 px line along its foot) inside
    // it, so the outline stays visible around the tint.
    final chip = DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HzRadius.r6),
          side: hairline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(HzLine.hairline),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(HzRadius.r6 - HzLine.hairline),
          child: HorizontSelectable(
            selected: on,
            edge: HorizontSelectionEdge.bottom,
            // Its Ink adds the selection line to the height below
            // minHeight, the outline adds a hairline above and below.
            minHeight: minHeight - 2 * HzLine.hairline - HzLine.selection,
            padding: const EdgeInsets.symmetric(
              horizontal: _padding,
              vertical: HzSpace.s8,
            ),
            onTap: () => onSelected(on && allowNone ? null : value),
            // Centred on the height, which can be more than one line of
            // text.
            child: Align(
              widthFactor: centred ? null : 1,
              child: Text(
                label,
                textAlign: centred ? TextAlign.center : null,
                style: _style(color, on),
              ),
            ),
          ),
        ),
      ),
    );
    // HorizontSelectable fills the width it is given; in a wrap a chip
    // keeps the width of its label.
    return centred ? chip : IntrinsicWidth(child: chip);
  }
}
