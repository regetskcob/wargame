import 'package:flutter/material.dart';

import '../../theme.dart';
import 'panel.dart';

class HealthBar extends StatelessWidget {
  const HealthBar({
    required this.hp,
    required this.maxHp,
    this.compact = false,
    super.key,
  });

  final double hp;
  final double maxHp;

  /// Smaller plate for phones held sideways.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ratio = (hp / maxHp).clamp(0.0, 1.0);
    final color = ratio > 0.3 ? const Color(0xFF9CCC65) : BwColors.danger;
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
            Row(
              children: [
                Icon(
                  Icons.health_and_safety,
                  size: compact ? 12 : 16,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  'PANZERUNG ${hp.ceil().clamp(0, maxHp.ceil())}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 11 : null,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 3 : 6),
            LinearProgressIndicator(
              value: ratio,
              minHeight: compact ? 7 : 10,
              backgroundColor: Colors.black38,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}
