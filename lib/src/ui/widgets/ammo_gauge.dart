import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../../game/special_weapon.dart';
import '../../game/game_config.dart';
import '../theme.dart';
import 'health_bar.dart';
import 'panel.dart';
import '../../l10n/l10n.dart';

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
    final status = endless
        ? null
        : ammo == 0
        ? HorizontStatus.critical
        : stockStatus(ratio, low: GameConfig.ammoLowShare);
    return _StockGauge(
      icon: Icons.inventory_2_outlined,
      label: endless
          ? tr('MUNITION ∞', 'AMMO ∞')
          : ammo == 0
          ? tr('MUNITION LEER', 'AMMO EMPTY')
          : tr('MUNITION $ammo/$maxAmmo', 'AMMO $ammo/$maxAmmo'),
      value: ratio,
      status: status,
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
    return _StockGauge(
      icon: Icons.local_gas_station_outlined,
      label: fuel <= 0
          ? tr('TANK LEER', 'TANK EMPTY')
          : tr(
              'TREIBSTOFF ${(fuel * 100).ceil()} %',
              'FUEL ${(fuel * 100).ceil()} %',
            ),
      value: fuel.clamp(0.0, 1.0),
      status: stockStatus(fuel, low: GameConfig.fuelLowShare),
    );
  }
}

/// One stock in its plate: icon, the value in mono with the sign of its
/// state, and the bar under it.
class _StockGauge extends StatelessWidget {
  const _StockGauge({
    required this.icon,
    required this.label,
    required this.value,
    required this.status,
  });

  final IconData icon;
  final String label;
  final double value;
  final HorizontStatus? status;

  @override
  Widget build(BuildContext context) {
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
                  icon,
                  size: HzIconSize.inline,
                  color: status == null ? GameColors.textMuted : color,
                ),
                const SizedBox(width: HzSpace.s4),
                Flexible(
                  child: Text(
                    label,
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
            GaugeBar(value: value, status: status),
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
      padding: const EdgeInsets.symmetric(
        horizontal: HzSpace.s12,
        vertical: HzSpace.s8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The colour of the gem's crate in the field, so the plate and
          // the pickup are recognised as one; the text stays in ink.
          Icon(
            Icons.diamond_outlined,
            size: HzIconSize.inline,
            color: weapon.color,
          ),
          const SizedBox(width: HzSpace.s8),
          Text(
            weapon.label,
            style: GameType.label.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: HzSpace.s8),
          Text('×$charges', style: GameType.data),
          if (keyHint != null) ...[
            const SizedBox(width: HzSpace.s8),
            DecoratedBox(
              decoration: ShapeDecoration(shape: GameShapes.chip()),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: HzSpace.s4,
                  vertical: HzSpace.s2,
                ),
                child: Text(keyHint!, style: GameType.kennung),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
