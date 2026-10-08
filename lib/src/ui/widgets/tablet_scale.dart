import 'dart:math';

import 'package:flutter/widgets.dart';

import '../../tv/tv_input.dart';

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

/// How much larger the Apple TV draws everything than a desktop browser on
/// a screen of the same size, as it is seen from across the room.
const tvScale = 1.4;

/// Lays [child] out on a screen smaller by [hudScaleFor] and draws it
/// magnified, so the phone layouts and their breakpoints work unchanged.
class TabletScale extends StatelessWidget {
  const TabletScale({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (onTv) {
      // The Apple TV scales the whole app already. Half a screen, as on a
      // split screen, takes the plates a bit smaller, so the field shows.
      return LayoutBuilder(
        builder: (context, box) =>
            FixedScale(scale: box.maxWidth < 900 ? 0.8 : 1, child: child),
      );
    }
    return FixedScale(
      scale: hudScaleFor(MediaQuery.sizeOf(context)),
      child: child,
    );
  }
}

/// Lays [child] out on a screen smaller by [scale] and draws it magnified.
class FixedScale extends StatelessWidget {
  const FixedScale({required this.scale, required this.child, super.key});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (scale == 1) {
      return child;
    }
    final media = MediaQuery.of(context);
    // The room it is given, which is the screen unless it shares it, as
    // the halves of a duel do.
    return LayoutBuilder(
      builder: (context, box) {
        final outer = Size(
          box.hasBoundedWidth ? box.maxWidth : media.size.width,
          box.hasBoundedHeight ? box.maxHeight : media.size.height,
        );
        return _scaled(media, outer);
      },
    );
  }

  Widget _scaled(MediaQueryData media, Size outer) {
    final inner = Size(outer.width / scale, outer.height / scale);
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
