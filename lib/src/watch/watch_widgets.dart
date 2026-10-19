import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_watchos/flutter_watchos.dart';
import 'package:horizont/horizont.dart';

import '../game/game_config.dart';
import '../ui/theme.dart';
import '../ui/widgets/health_bar.dart';
import 'watch_support.dart';

/// How far the watch screens keep their content from the edge: the system's
/// padding, and on a round screen at least the corners of the largest square
/// inside the circle, so nothing runs into the rim.
EdgeInsets watchInsets(BuildContext context) {
  final padding = MediaQuery.paddingOf(context);
  if (!watchRound) {
    return padding;
  }
  final corner = MediaQuery.sizeOf(context).shortestSide * (1 - sqrt1_2) / 2;
  return EdgeInsets.fromLTRB(
    max(padding.left, corner),
    max(padding.top, corner),
    max(padding.right, corner),
    max(padding.bottom, corner),
  );
}

/// The page behind every watch menu: the Gelände ground, a list that the
/// crown scrolls, and room around the corners and under the clock, or
/// inside the circle of a round watch.
class WatchPage extends StatelessWidget {
  const WatchPage({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final insets = watchInsets(context);
    return ColoredBox(
      color: GameColors.bg,
      child: ListView(
        padding: watchRound
            // The first and last entries scroll fully into the circle.
            ? insets
            : EdgeInsets.fromLTRB(
                HzSpace.s12 + padding.left,
                // Under the clock, which watchOS draws over the app.
                WatchStatusBar.heightOf(context) + HzSpace.s4,
                HzSpace.s12 + padding.right,
                HzSpace.s16 + padding.bottom,
              ),
        children: children,
      ),
    );
  }
}

/// A button the full width of the watch, tall enough for a thumb.
class WatchButton extends StatelessWidget {
  const WatchButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.danger = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    // The one action of a screen in the accent, every other in ink on
    // the hairline, an irreversible one in critical.
    const style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size.fromHeight(HzSize.touch)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: HzSpace.s8),
      ),
    );
    final text = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        // The button's own colour, the label's size and weight.
        style: TextStyle(
          fontSize: GameType.label.fontSize,
          height: GameType.label.height,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: HzIconSize.row),
          const SizedBox(width: HzSpace.s8),
        ],
        Flexible(child: text),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: HzSpace.s8),
      child: primary
          ? FilledButton(onPressed: onPressed, style: style, child: child)
          : OutlinedButton(
              onPressed: onPressed,
              style: danger
                  ? style.copyWith(
                      foregroundColor: const WidgetStatePropertyAll(
                        GameColors.critical,
                      ),
                      side: const WidgetStatePropertyAll(
                        BorderSide(color: GameColors.critical),
                      ),
                    )
                  : style,
              child: child,
            ),
    );
  }
}

/// A small heading over a block of a menu: a Kennung.
class WatchLabel extends StatelessWidget {
  const WatchLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: HzSpace.s4, bottom: HzSpace.s8),
    child: Kennung(text),
  );
}

/// Armour and magazine as two arcs along the rim of a round watch, where a
/// bar would lose its ends to the circle: armour on the left, filling from
/// the bottom, the magazine on the right. Without [ammo] (shells never run
/// out) only the armour shows.
class WatchRimPainter extends CustomPainter {
  WatchRimPainter({required this.armour, this.ammo});

  /// Share of armour left, 0 to 1.
  final double armour;

  /// Share of the magazine left, 0 to 1, or null when it never runs out.
  final double? ammo;

  /// Each arc covers this much of the circle (radians), a sixth, so the
  /// inventory along the bottom and the status at the top stay clear.
  static const sweep = pi / 3;

  static const width = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2 - width / 2 - 3;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: radius,
    );
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = GameColors.sunken.withValues(alpha: 0.7);
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    // Angles run clockwise from three o'clock, with y down. Both arcs
    // start at their lower end and fill upwards: clockwise on the left,
    // anticlockwise on the right.
    const left = pi - sweep / 2;
    canvas.drawArc(rect, left, sweep, false, track);
    final share = armour.clamp(0.0, 1.0);
    if (share > 0) {
      // Ink while there is enough, warning and critical as on the HUD.
      fill.color = stockColor(armourStatus(share));
      canvas.drawArc(rect, left, sweep * share, false, fill);
    }
    final magazine = ammo;
    if (magazine == null) {
      return;
    }
    const right = sweep / 2;
    canvas.drawArc(rect, right, -sweep, false, track);
    final rounds = magazine.clamp(0.0, 1.0);
    if (rounds > 0) {
      fill.color = stockColor(
        stockStatus(rounds, low: GameConfig.ammoLowShare),
      );
      canvas.drawArc(rect, right, -sweep * rounds, false, fill);
    }
  }

  @override
  bool shouldRepaint(WatchRimPainter old) =>
      old.armour != armour || old.ammo != ammo;
}
