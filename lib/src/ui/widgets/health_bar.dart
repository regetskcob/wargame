import 'package:flutter/material.dart';

import '../theme.dart';
import 'panel.dart';
import '../../l10n/l10n.dart';

class HealthBar extends StatelessWidget {
  const HealthBar({required this.hp, required this.maxHp, super.key});

  final double hp;
  final double maxHp;

  @override
  Widget build(BuildContext context) {
    final ratio = (hp / maxHp).clamp(0.0, 1.0);
    final color = ratio > 0.3 ? const Color(0xFF9CCC65) : GameColors.danger;
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
                Icon(Icons.health_and_safety_outlined, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  tr(
                    'PANZERUNG ${hp.ceil().clamp(0, maxHp.ceil())}',
                    'ARMOUR ${hp.ceil().clamp(0, maxHp.ceil())}',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: Colors.black38,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}
