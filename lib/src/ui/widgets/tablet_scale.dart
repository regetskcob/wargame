import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:horizont/horizont.dart';

import '../../tv/tv_input.dart';

/// Shortest side from which a screen counts as a tablet.
const tabletShortSide = 600.0;

/// Whether this device has a phone's screen. Only phones serve as the
/// controller of a game elsewhere: a tablet shows the game itself and pairs
/// a phone of its own. Read from the device, not the window, so it holds
/// before the first frame and whichever way the device is held. A Mac is
/// never one, however small its window: it opens pairing links too.
bool get deviceIsPhone {
  if (defaultTargetPlatform
      case TargetPlatform.macOS ||
          TargetPlatform.windows ||
          TargetPlatform.linux) {
    return false;
  }
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  return view.physicalSize.shortestSide / view.devicePixelRatio <
      tabletShortSide;
}

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

/// How much the menus outside the round grow on [size]. Only large tablets
/// grow, up to 1.25 on a 13" iPad, so the menus read at arm's length as on
/// a phone. Phones, the 11" iPad and a browser of 1280 by 800 keep 1, and
/// the layouts and breakpoints of the menus stay those of the smaller
/// screen.
double menuScaleFor(Size size) {
  final short = min(size.width, size.height);
  final scale = (short / 820).clamp(1.0, 1.25);
  // Barely larger is not worth a blurred edge.
  return short < tabletShortSide || scale < 1.05 ? 1 : scale;
}

/// How much larger the Apple TV draws everything than a desktop browser on
/// a screen of the same size, as it is seen from across the room: Horizont's
/// type scale for the television.
const tvScale = HzTv.typeScale;

/// The scale for a television of [screen] logical pixels. The Apple TV is
/// always 1920 wide, Android TV mostly 960 (1080p at twice the density), so
/// the menus get the same 1280 points of width on both and keep the
/// layouts tried on the Apple TV.
double tvScaleFor(Size screen) =>
    screen.width <= 0 ? tvScale : screen.width * tvScale / 1920;

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
    // Half the screen, when two play side by side: a bit smaller instead
    // of the tablet's magnifying, so the field shows.
    final screen = MediaQuery.sizeOf(context);
    return LayoutBuilder(
      builder: (context, box) => FixedScale(
        scale:
            box.maxWidth < screen.width - 1 || box.maxHeight < screen.height - 1
            ? 0.85
            : hudScaleFor(box.biggest),
        child: child,
      ),
    );
  }
}

/// Lays a menu out on a screen smaller by [menuScaleFor] and draws it
/// magnified. The television scales the whole app already.
class MenuScale extends StatelessWidget {
  const MenuScale({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => onTv
      ? child
      : FixedScale(
          scale: menuScaleFor(MediaQuery.sizeOf(context)),
          child: child,
        );
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

/// Horizont's safe margin of a television, `HzTv.safeVertical` above and
/// below and `HzTv.safeHorizontal` at the sides, given to everything below
/// as the screen's padding: menus and HUD keep inside it through their
/// `SafeArea`, while the round itself still fills the whole panel.
class TvSafeArea extends StatelessWidget {
  const TvSafeArea({required this.child, super.key});

  final Widget child;

  static const margin = EdgeInsets.symmetric(
    horizontal: HzTv.safeHorizontal,
    vertical: HzTv.safeVertical,
  );

  static EdgeInsets _atLeast(EdgeInsets a) => EdgeInsets.fromLTRB(
    max(a.left, margin.left),
    max(a.top, margin.top),
    max(a.right, margin.right),
    max(a.bottom, margin.bottom),
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        padding: _atLeast(media.padding),
        viewPadding: _atLeast(media.viewPadding),
      ),
      child: child,
    );
  }
}
