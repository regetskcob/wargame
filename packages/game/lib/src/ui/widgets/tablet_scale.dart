import 'dart:math';

import 'package:flutter/widgets.dart';

/// Shortest side from which a screen counts as a tablet.
const tabletShortSide = 600.0;

/// How much the in-game HUD grows on [size]. Phones keep 1, tablets scale
/// with their shorter side up to 1.4, so plates, sticks and buttons stay as
/// easy to read and hit as on a phone.
double hudScaleFor(Size size) {
  final short = min(size.width, size.height);
  if (short < tabletShortSide) {
    return 1;
  }
  return (short / 430).clamp(1.0, 1.4);
}

/// Lays [child] out on a screen smaller by [hudScaleFor] and draws it
/// magnified, so the phone layouts and their breakpoints work unchanged.
class TabletScale extends StatelessWidget {
  const TabletScale({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = hudScaleFor(media.size);
    if (scale == 1) {
      return child;
    }
    final inner = Size(media.size.width / scale, media.size.height / scale);
    return Transform.scale(
      scale: scale,
      alignment: Alignment.topLeft,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: inner.width,
        maxWidth: inner.width,
        minHeight: inner.height,
        maxHeight: inner.height,
        child: MediaQuery(
          data: media.copyWith(
            size: inner,
            padding: media.padding / scale,
            viewPadding: media.viewPadding / scale,
            viewInsets: media.viewInsets / scale,
            systemGestureInsets: media.systemGestureInsets / scale,
          ),
          child: child,
        ),
      ),
    );
  }
}
