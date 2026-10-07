import 'package:flutter/material.dart';

import '../../theme.dart';

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
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: BwColors.oliveLight, width: 1.5),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
