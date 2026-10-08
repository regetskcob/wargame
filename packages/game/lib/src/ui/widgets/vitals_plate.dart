import 'package:flutter/material.dart';

import '../../game_config.dart';
import '../../theme.dart';
import 'panel.dart';

/// Phones: armour, shells and fuel in one small plate, a line each with an
/// icon, a thin bar and the value. The same warnings as the big gauges, in
/// a third of their height.
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

  /// The easy level: shells never run out.
  final bool endless;

  /// Share of a full tank, null on the level without fuel.
  final double? fuel;

  @override
  Widget build(BuildContext context) {
    final armour = (hp / maxHp).clamp(0.0, 1.0);
    final shells = endless
        ? 1.0
        : maxAmmo == 0
        ? 0.0
        : (ammo / maxAmmo).clamp(0.0, 1.0);
    final tank = fuel;
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      child: SizedBox(
        width: 112,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _line(
              Icons.health_and_safety,
              armour,
              armour > 0.3 ? const Color(0xFF9CCC65) : BwColors.danger,
              '${hp.ceil().clamp(0, maxHp.ceil())}',
            ),
            _line(
              Icons.inventory_2,
              shells,
              endless
                  ? const Color(0xFF4FC3F7)
                  : ammo == 0
                  ? BwColors.danger
                  : shells <= GameConfig.ammoLowShare
                  ? BwColors.amber
                  : const Color(0xFF4FC3F7),
              endless ? '∞' : '$ammo',
            ),
            if (tank != null)
              _line(
                Icons.local_gas_station,
                tank.clamp(0.0, 1.0),
                tank <= 0
                    ? BwColors.danger
                    : tank <= GameConfig.fuelLowShare
                    ? BwColors.amber
                    : const Color(0xFFFF9100),
                '${(tank * 100).ceil()}%',
              ),
          ],
        ),
      ),
    );
  }

  Widget _line(IconData icon, double value, Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: Colors.black38,
              color: color,
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              label,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: value <= 0 ? BwColors.danger : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
