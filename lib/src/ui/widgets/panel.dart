import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../theme.dart';

/// The shapes of every box in the game, Horizont's soft style: no bevels, no
/// shadows, one quiet hairline in `line`. A free-standing card or plate takes
/// the card radius (`HzSoft.card`, 14), whatever stands in a row with buttons
/// and fields (a slot, a chip, a plate inside a panel) takes their radius
/// (`HzSoft.control`, 12).
class GameShapes {
  static RoundedRectangleBorder card({
    Color? edge,
    double width = HzLine.hairline,
  }) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(HzSoft.card),
    side: BorderSide(color: edge ?? GameColors.line, width: width),
  );

  static RoundedRectangleBorder chip({
    Color? edge,
    double width = HzLine.hairline,
  }) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(HzSoft.control),
    side: BorderSide(color: edge ?? GameColors.line, width: width),
  );
}

/// A box inside a page or panel: sunken ground, the radius of the buttons
/// beside it.
class Plate extends StatelessWidget {
  const Plate({
    required this.child,
    this.padding = const EdgeInsets.all(HzSpace.s12),
    this.color,
    this.edge,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// The ground; [GameColors.sunken] by default.
  final Color? color;

  /// The outline; [GameColors.line] by default.
  final Color? edge;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color ?? GameColors.sunken,
        shape: GameShapes.chip(edge: edge),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// The plate of every HUD element and floating menu: the surface, a little
/// see-through over the round, with the one outline.
class Panel extends StatelessWidget {
  const Panel({
    required this.child,
    this.padding = const EdgeInsets.all(HzSpace.s16),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: GameColors.panel,
        shape: GameShapes.card(),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
