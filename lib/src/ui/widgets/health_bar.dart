import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../theme.dart';
import 'panel.dart';
import '../../l10n/l10n.dart';

/// The state of a stock (armour, shells, fuel) as Horizont says it: nothing
/// while there is enough, warning once it runs low, critical when it is
/// nearly or fully gone. Callers show the sign of the state beside the
/// value, so it never rests on the colour of the bar alone.
HorizontStatus? stockStatus(
  double share, {
  required double low,
  double critical = 0,
}) {
  if (share <= critical) {
    return HorizontStatus.critical;
  }
  if (share <= low) {
    return HorizontStatus.warning;
  }
  return null;
}

/// The colour of a stock in [status]: ink while there is enough.
Color stockColor(HorizontStatus? status) => switch (status) {
  HorizontStatus.critical => GameColors.critical,
  HorizontStatus.warning => GameColors.warning,
  _ => GameColors.text,
};

/// The armour that is left: warning at half, critical below a third.
HorizontStatus? armourStatus(double share) =>
    stockStatus(share, low: 0.5, critical: 0.3);

/// A bar of the HUD: the fill in ink (or the colour of its state) on a
/// sunken track, square ends with the radius of a status mark. No
/// animation, the value follows the round.
class GaugeBar extends StatelessWidget {
  const GaugeBar({
    required this.value,
    this.status,
    this.height = HzSpace.s8,
    this.color,
    super.key,
  });

  /// Share filled, 0 to 1.
  final double value;
  final HorizontStatus? status;
  final double height;

  /// A fill of the world's own in place of ink, such as a team colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(HzRadius.r2);
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: GameColors.sunken,
          borderRadius: radius,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color ?? stockColor(status),
                borderRadius: radius,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The sign of a stock's state beside its value, or nothing while there is
/// enough.
class StockSign extends StatelessWidget {
  const StockSign(this.status, {this.size = HzIconSize.inline, super.key});

  final HorizontStatus? status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final state = status;
    if (state == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: HzSpace.s4),
      child: Icon(state.icon, size: size, color: stockColor(state)),
    );
  }
}

class HealthBar extends StatelessWidget {
  const HealthBar({required this.hp, required this.maxHp, super.key});

  final double hp;
  final double maxHp;

  @override
  Widget build(BuildContext context) {
    final ratio = (hp / maxHp).clamp(0.0, 1.0);
    final status = armourStatus(ratio);
    final color = stockColor(status);
    return SizedBox(
      width: 220,
      child: Panel(
        padding: const EdgeInsets.symmetric(
          horizontal: HzSpace.s12,
          vertical: HzSpace.s8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  HorizontSymbols.healthAndSafety,
                  size: HzIconSize.inline,
                  color: status == null ? GameColors.textMuted : color,
                ),
                const SizedBox(width: HzSpace.s4),
                // Never past the plate, whatever the font makes of a
                // four-digit armour.
                Flexible(
                  child: Text(
                    tr(
                      'PANZERUNG ${hp.ceil().clamp(0, maxHp.ceil())}',
                      'ARMOUR ${hp.ceil().clamp(0, maxHp.ceil())}',
                    ),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: GameType.data.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                StockSign(status),
              ],
            ),
            const SizedBox(height: HzSpace.s4),
            GaugeBar(value: ratio, status: status),
          ],
        ),
      ),
    );
  }
}
