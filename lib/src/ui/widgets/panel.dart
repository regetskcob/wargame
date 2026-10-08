import 'package:flutter/material.dart';

import '../theme.dart';

/// The one shape of every box in the game: beveled corners and a light olive
/// edge. Cards use the large bevel, chips and slots the small one.
class BwShapes {
  static BeveledRectangleBorder card({
    Color edge = BwColors.oliveLight,
    double width = 1.5,
  }) => BeveledRectangleBorder(
    borderRadius: BorderRadius.circular(8),
    side: BorderSide(color: edge, width: width),
  );

  static BeveledRectangleBorder chip({
    Color edge = BwColors.oliveLight,
    double width = 1.5,
  }) => BeveledRectangleBorder(
    borderRadius: BorderRadius.circular(6),
    side: BorderSide(color: edge, width: width),
  );
}

/// A card inside a page or panel: darker ground, the same shape as the rest.
class Plate extends StatelessWidget {
  const Plate({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = const Color(0x44000000),
    this.edge = BwColors.oliveLight,
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
        shape: BwShapes.card(edge: edge),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Dark olive plate with a sand coloured edge, the base of every HUD element.
class Panel extends StatelessWidget {
  const Panel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: BwColors.panel,
        shape: BwShapes.card(),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
