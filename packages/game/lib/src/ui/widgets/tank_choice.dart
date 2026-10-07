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
    this.width = 112,
    this.locked = false,
    super.key,
  });

  final TankType type;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final double width;

  /// The pilot's rank is too low for it yet.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final card = InkWell(
      onTap: locked ? null : onTap,
      child: Container(
        width: width,
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
              locked ? 'ab Stufe ${type.level}' : type.role,
              style: TextStyle(
                fontSize: 10,
                color: locked ? BwColors.amber : BwColors.textDim,
              ),
            ),
          ],
        ),
      ),
    );
    if (!locked) {
      return card;
    }
    return Tooltip(
      message: '${type.label}: freigeschaltet ab Stufe ${type.level}',
      child: Stack(
        children: [
          Opacity(opacity: 0.45, child: card),
          const Positioned(
            right: 8,
            top: 8,
            child: Icon(Icons.lock, size: 18, color: BwColors.amber),
          ),
        ],
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

  /// The bars of [type], each against the best vehicle in that stat.
  static List<(String, double)> rowsOf(TankType type) {
    final stats = TankStats.of(type);
    return [
      ('PANZERUNG', stats.maxHp / _max((s) => s.maxHp)),
      ('TEMPO', stats.speed / _max((s) => s.speed)),
      ('WENDIGKEIT', stats.turnRate / _max((s) => s.turnRate)),
      ('FEUERKRAFT', stats.dps / _max((s) => s.dps)),
    ];
  }

  /// Overall strength: the bars added up.
  static double strengthOf(TankType type) =>
      rowsOf(type).fold(0.0, (sum, row) => sum + row.$2);

  /// The vehicles in the order a pilot gets them: by the rank that unlocks
  /// them, and among those of one rank from the weakest to the strongest.
  /// The enum keeps its order, its index travels over the wire.
  static final List<TankType> byUnlock = [...TankType.values]
    ..sort((a, b) {
      final rank = a.level.compareTo(b.level);
      return rank != 0 ? rank : strengthOf(a).compareTo(strengthOf(b));
    });

  @override
  Widget build(BuildContext context) {
    final stats = TankStats.of(type);
    final rows = rowsOf(type);
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
