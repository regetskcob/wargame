import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/components/tank_painter.dart';
import '../../game/tank_stats.dart';
import '../../theme.dart';

class TankChoice extends StatelessWidget {
  const TankChoice({
    required this.type,
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final TankType type;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 112,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: ShapeDecoration(
          color: selected ? const Color(0x33FFB300) : const Color(0x55000000),
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: selected ? BwColors.amber : BwColors.oliveLight,
              width: selected ? 2.5 : 1.5,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 96,
              height: 92,
              child: CustomPaint(painter: TankPreviewPainter(type, color)),
            ),
            const SizedBox(height: 4),
            Text(
              type.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            Text(
              type.role,
              style: const TextStyle(fontSize: 10, color: BwColors.textDim),
            ),
          ],
        ),
      ),
    );
  }
}

class TankPreviewPainter extends CustomPainter {
  const TankPreviewPainter(this.type, this.color);

  final TankType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const tank = 62.0;
    canvas.translate((size.width - tank) / 2, size.height - tank - 4);
    paintTank(canvas, tank, type, color);
  }

  @override
  bool shouldRepaint(TankPreviewPainter old) =>
      old.type != type || old.color != color;
}

/// Bars that compare the selected vehicle with the strongest of each stat.
class StatBars extends StatelessWidget {
  const StatBars({required this.type, super.key});

  final TankType type;

  static double _max(double Function(TankStats) read) =>
      TankType.values.map((t) => read(TankStats.of(t))).reduce(max);

  @override
  Widget build(BuildContext context) {
    final stats = TankStats.of(type);
    final rows = [
      ('PANZERUNG', stats.maxHp / _max((s) => s.maxHp)),
      ('TEMPO', stats.speed / _max((s) => s.speed)),
      ('WENDIGKEIT', stats.turnRate / _max((s) => s.turnRate)),
      ('FEUERKRAFT', stats.dps / _max((s) => s.dps)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          stats.blurb,
          style: const TextStyle(color: BwColors.textDim, fontSize: 12),
        ),
        const SizedBox(height: 8),
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 104,
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 11, letterSpacing: 1),
                  ),
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    value: value.clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: Colors.black38,
                    color: BwColors.amber,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
