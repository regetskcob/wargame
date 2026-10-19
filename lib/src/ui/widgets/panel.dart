import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../theme.dart';

/// The shapes of every box in the game, Horizont's: no bevels, no shadows,
/// one hairline in the outline colour. A free-standing card or plate takes
/// radius 10, whatever stands in a row with buttons and fields (a slot, a
/// chip, a plate inside a panel) takes their radius 6.
class GameShapes {
  static RoundedRectangleBorder card({
    Color edge = GameColors.lineStrong,
    double width = HzLine.hairline,
  }) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(HzRadius.r10),
    side: BorderSide(color: edge, width: width),
  );

  static RoundedRectangleBorder chip({
    Color edge = GameColors.lineStrong,
    double width = HzLine.hairline,
  }) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(HzRadius.r6),
    side: BorderSide(color: edge, width: width),
  );
}

/// A box inside a page or panel: sunken ground, the radius of the buttons
/// beside it.
class Plate extends StatelessWidget {
  const Plate({
    required this.child,
    this.padding = const EdgeInsets.all(HzSpace.s12),
    this.color = GameColors.sunken,
    this.edge = GameColors.lineStrong,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color edge;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color,
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
