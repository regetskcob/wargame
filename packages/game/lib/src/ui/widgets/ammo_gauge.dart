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
    this.compact = false,
    super.key,
  });

  final int ammo;
  final int maxAmmo;

  /// Smaller plate for phones held sideways.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ratio = maxAmmo == 0 ? 0.0 : (ammo / maxAmmo).clamp(0.0, 1.0);
    final low = ratio <= GameConfig.ammoLowShare;
    final color = ammo == 0
        ? BwColors.danger
        : low
        ? BwColors.amber
        : const Color(0xFF4FC3F7);
    return SizedBox(
      width: compact ? 150 : 220,
      child: Panel(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ammo == 0 ? 'MUNITION LEER' : 'MUNITION $ammo/$maxAmmo',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: compact ? 11 : null,
                color: ammo == 0 ? BwColors.danger : null,
              ),
            ),
            SizedBox(height: compact ? 3 : 6),
            LinearProgressIndicator(
              value: ratio,
              minHeight: compact ? 5 : 7,
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
              decoration: BoxDecoration(
                border: Border.all(color: BwColors.sand),
                borderRadius: BorderRadius.circular(3),
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
