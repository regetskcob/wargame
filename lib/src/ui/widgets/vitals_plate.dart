import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../../game/game_config.dart';
import '../theme.dart';
import 'health_bar.dart';
import 'panel.dart';

/// Phones: armour, shells and fuel in one small plate, a line each with an
/// icon, a thin bar and the value. The same warnings as the big gauges, in
/// a third of their height: the bar and the value turn warning or critical,
/// and the icon gives way to the sign of that state.
class VitalsPlate extends StatelessWidget {
  const VitalsPlate({
    required this.hp,
    required this.maxHp,
    required this.ammo,
    required this.maxAmmo,
    required this.endless,
    this.fuel,
    super.key,
  });

  final double hp;
  final double maxHp;
  final int ammo;
  final int maxAmmo;

  /// The easy level: shells never run out, and the line for them is left
  /// out, it would only take room.
  final bool endless;

  /// Share of a full tank, null on the level without fuel.
  final double? fuel;

  /// The plate with its padding, for the panels that must stay beside it.
  static const outerWidth = 112.0 + 2 * HzSpace.s8;

  @override
  Widget build(BuildContext context) {
    final armour = (hp / maxHp).clamp(0.0, 1.0);
    final shells = maxAmmo == 0 ? 0.0 : (ammo / maxAmmo).clamp(0.0, 1.0);
    final tank = fuel;
    return Panel(
      padding: const EdgeInsets.symmetric(
        horizontal: HzSpace.s8,
        vertical: HzSpace.s4,
      ),
      child: SizedBox(
        width: 112,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _line(
              HorizontSymbols.healthAndSafety,
              armour,
              armourStatus(armour),
              '${hp.ceil().clamp(0, maxHp.ceil())}',
            ),
            if (!endless)
              _line(
                HorizontSymbols.inventory2,
                shells,
                ammo == 0
                    ? HorizontStatus.critical
                    : stockStatus(shells, low: GameConfig.ammoLowShare),
                '$ammo',
              ),
            if (tank != null)
              _line(
                HorizontSymbols.localGasStation,
                tank.clamp(0.0, 1.0),
                stockStatus(tank, low: GameConfig.fuelLowShare),
                '${(tank * 100).ceil()} %',
              ),
          ],
        ),
      ),
    );
  }

  Widget _line(
    IconData icon,
    double value,
    HorizontStatus? status,
    String label,
  ) {
    final color = stockColor(status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HzSpace.s2),
      child: Row(
        children: [
          // In this small plate the sign takes the place of the icon: the
          // order of the lines still says which stock it is.
          Icon(
            status?.icon ?? icon,
            size: HzIconSize.badge,
            color: status == null ? GameColors.textMuted : color,
          ),
          const SizedBox(width: HzSpace.s4),
          Expanded(
            child: GaugeBar(value: value, status: status, height: HzSpace.s4),
          ),
          SizedBox(
            // Room for "100 %" in mono without the tracking of a Kennung.
            width: 36,
            child: Text(
              label,
              textAlign: TextAlign.end,
              maxLines: 1,
              softWrap: false,
              style: GameType.kennung.copyWith(color: color, letterSpacing: 0),
            ),
          ),
        ],
      ),
    );
  }
}
