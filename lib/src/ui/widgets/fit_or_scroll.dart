import 'package:flutter/widgets.dart';

import '../../tv/tv_input.dart';

/// A page that may be taller than the screen. It scrolls, except on the
/// Apple TV: there it shrinks until it fits, as scrolling with a remote is
/// tedious and the screen is wide enough for the layouts to stay short.
class FitOrScroll extends StatelessWidget {
  const FitOrScroll({
    required this.child,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (!onTv) {
      return SingleChildScrollView(padding: padding, child: child);
    }
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, box) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: box.maxWidth,
            // Narrow panels keep their width, in the middle.
            child: Align(alignment: Alignment.topCenter, child: child),
          ),
        ),
      ),
    );
  }
}
