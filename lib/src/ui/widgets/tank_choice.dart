import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/components/tank_painter.dart';
import '../../game/tank_stats.dart';
import '../theme.dart';
import '../../l10n/l10n.dart';

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

  /// One line of text [height] high, shrunk to fit instead of wrapping.
  static Widget _line(String text, TextStyle style, double height) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: SizedBox(
      height: height,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, style: style, maxLines: 1, softWrap: false),
      ),
    ),
  );

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
            // The same width for all: a thicker border would make the
            // selected card bigger than the others.
            side: BorderSide(
              color: selected ? GameColors.amber : GameColors.oliveLight,
              width: 2,
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
            // One line each, shrunk to fit, so every card has the same
            // height however long the name is.
            _line(
              type.label,
              const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
              17,
            ),
            _line(
              locked
                  ? tr('ab Stufe ${type.level}', 'from level ${type.level}')
                  : type.role,
              TextStyle(
                fontSize: 11,
                color: locked ? GameColors.amber : GameColors.textDim,
              ),
              14,
            ),
          ],
        ),
      ),
    );
    if (!locked) {
      return card;
    }
    return Tooltip(
      message: tr(
        '${type.label}: freigeschaltet ab Stufe ${type.level}',
        '${type.label}: unlocked from level ${type.level}',
      ),
      child: Stack(
        children: [
          Opacity(opacity: 0.45, child: card),
          const Positioned(
            right: 8,
            top: 8,
            child: Icon(Icons.lock, size: 18, color: GameColors.amber),
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
      (tr('PANZERUNG', 'ARMOUR'), stats.maxHp / _max((s) => s.maxHp)),
      (tr('TEMPO', 'SPEED'), stats.speed / _max((s) => s.speed)),
      (tr('WENDIGKEIT', 'AGILITY'), stats.turnRate / _max((s) => s.turnRate)),
      (tr('FEUERKRAFT', 'FIREPOWER'), stats.dps / _max((s) => s.dps)),
    ];
  }

  /// Overall strength: the bars added up.
  static double strengthOf(TankType type) =>
      rowsOf(type).fold(0.0, (sum, row) => sum + row.$2);

  /// The vehicles as the lobby lists them: first those the pilot may drive,
  /// from the weakest to the strongest, then the locked ones by the rank
  /// they need and among one rank by strength.
  /// The enum keeps its order, its index travels over the wire.
  static List<TankType> ordered(bool Function(TankType) unlocked) =>
      [...TankType.values]..sort((a, b) {
        final open = (unlocked(a) ? 0 : 1).compareTo(unlocked(b) ? 0 : 1);
        if (open != 0) {
          return open;
        }
        final rank = unlocked(a) ? 0 : a.level.compareTo(b.level);
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
          style: const TextStyle(color: GameColors.textDim, fontSize: 12),
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
                    color: GameColors.amber,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
