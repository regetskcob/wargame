import 'package:flutter/material.dart';

import '../../game/special_weapon.dart';
import '../../game_config.dart';
import '../../theme.dart';
import 'panel.dart';

/// Rounds left in the magazine, warning once it runs low.
class AmmoGauge extends StatelessWidget {
  const AmmoGauge({
    required this.ammo,
    required this.maxAmmo,
    this.endless = false,
    super.key,
  });

  final int ammo;
  final int maxAmmo;

  /// The easy level: shells never run out.
  final bool endless;

  @override
  Widget build(BuildContext context) {
    final ratio = endless
        ? 1.0
        : maxAmmo == 0
        ? 0.0
        : (ammo / maxAmmo).clamp(0.0, 1.0);
    final low = ratio <= GameConfig.ammoLowShare;
    final color = endless
        ? const Color(0xFF4FC3F7)
        : ammo == 0
        ? BwColors.danger
        : low
        ? BwColors.amber
        : const Color(0xFF4FC3F7);
    return SizedBox(
      width: 220,
      child: Panel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  endless
                      ? 'MUNITION ∞'
                      : ammo == 0
                      ? 'MUNITION LEER'
                      : 'MUNITION $ammo/$maxAmmo',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,

                    color: ammo == 0 && !endless ? BwColors.danger : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: Colors.black38,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

/// Fuel left in the tank, warning once it runs low.
class FuelGauge extends StatelessWidget {
  const FuelGauge({required this.fuel, super.key});

  /// Share of a full tank, 0 to 1.
  final double fuel;

  @override
  Widget build(BuildContext context) {
    final low = fuel <= GameConfig.fuelLowShare;
    final color = fuel <= 0
        ? BwColors.danger
        : low
        ? BwColors.amber
        : const Color(0xFFFF9100);
    return SizedBox(
      width: 220,
      child: Panel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.local_gas_station, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  fuel <= 0
                      ? 'TANK LEER'
                      : 'TREIBSTOFF ${(fuel * 100).ceil()} %',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,

                    color: fuel <= 0 ? BwColors.danger : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: fuel.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: Colors.black38,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

/// The special weapon from a gem and its charges, with the key to fire it.
class SpecialPlate extends StatelessWidget {
  const SpecialPlate({
    required this.weapon,
    required this.charges,
    this.keyHint,
    super.key,
  });

  final SpecialWeapon weapon;
  final int charges;
  final String? keyHint;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.diamond, size: 16, color: weapon.color),
          const SizedBox(width: 8),
          Text(
            '${weapon.label}  ×$charges',
            style: TextStyle(fontWeight: FontWeight.w800, color: weapon.color),
          ),
          if (keyHint != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: ShapeDecoration(
                shape: BeveledRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                  side: const BorderSide(color: BwColors.sand),
                ),
              ),
              child: Text(
                keyHint!,
                style: const TextStyle(fontSize: 11, color: BwColors.sand),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
