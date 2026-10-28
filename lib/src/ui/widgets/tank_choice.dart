import 'dart:math';

import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

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

  /// The widest a card grows on a large screen: four of them fill an
  /// upright tablet, where the waiting room gives them the whole width.
  static const maxWidth = 200.0;

  /// One line of text [height] high, shrunk to fit instead of wrapping.
  static Widget _line(String text, TextStyle style, double height) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: HzSpace.s8),
    child: SizedBox(
      height: height,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, style: style, maxLines: 1, softWrap: false),
      ),
    ),
  );

  double get _grow => (width / 112).clamp(1.0, maxWidth / 112);

  @override
  Widget build(BuildContext context) {
    final card = InkWell(
      onTap: locked ? null : onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: HzSpace.s8),
        // Horizont's selection on cards: the chosen one on the accent tint
        // with a 2 px outline in the accent and a tick, the others with the
        // hairline. The selection ring is painted over the card, so nothing
        // moves on picking.
        decoration: BoxDecoration(
          color: selected ? GameColors.accentTint : GameColors.sunken,
          borderRadius: BorderRadius.circular(HzRadius.r10),
          border: Border.all(color: GameColors.lineStrong),
        ),
        foregroundDecoration: selected
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(HzRadius.r10),
                border: Border.all(
                  color: GameColors.accentText,
                  width: HzLine.selection,
                ),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The tank grows with a card wider than the default, so a wide
            // card is not a small tank in a lot of air.
            SizedBox(
              width: 96 * _grow,
              height: 92 * _grow,
              child: CustomPaint(
                painter: TankPreviewPainter(type, color, scale: _grow),
              ),
            ),
            const SizedBox(height: 4),
            // One line each, shrunk to fit, so every card has the same
            // height however long the name is.
            _line(
              type.label,
              GameType.label.copyWith(fontWeight: FontWeight.w600),
              17,
            ),
            _line(
              locked
                  ? tr('ab Stufe ${type.level}', 'from level ${type.level}')
                  : type.role,
              GameType.caption,
              14,
            ),
          ],
        ),
      ),
    );
    if (!locked) {
      if (!selected) {
        return card;
      }
      return Stack(
        children: [
          card,
          Positioned(
            right: HzSpace.s8,
            top: HzSpace.s8,
            child: Icon(
              HorizontSymbols.check,
              size: HzIconSize.row,
              color: GameColors.accentText,
            ),
          ),
        ],
      );
    }
    return Tooltip(
      message: tr(
        '${type.label}: freigeschaltet ab Stufe ${type.level}',
        '${type.label}: unlocked from level ${type.level}',
      ),
      child: Stack(
        children: [
          Opacity(opacity: 0.45, child: card),
          Positioned(
            right: HzSpace.s8,
            top: HzSpace.s8,
            child: Icon(
              HorizontSymbols.lock,
              size: HzIconSize.row,
              color: GameColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class TankPreviewPainter extends CustomPainter {
  const TankPreviewPainter(this.type, this.color, {this.scale = 1});

  final TankType type;
  final Color color;

  /// How much larger than the default 62 the tank is drawn.
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final tank = 62.0 * scale;
    canvas.translate((size.width - tank) / 2, size.height - tank - 4);
    paintTank(canvas, tank, type, color);
  }

  @override
  bool shouldRepaint(TankPreviewPainter old) =>
      old.type != type || old.color != color || old.scale != scale;
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
        Text(stats.blurb, style: GameType.caption),
        const SizedBox(height: HzSpace.s8),
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: HzSpace.s4),
            child: Row(
              children: [
                // A term column of fixed width, so the bars stand flush.
                SizedBox(
                  width: 104,
                  child: Text(label, style: GameType.kennung),
                ),
                // Values in ink on a sunken track: a comparison, not a
                // selection, so no accent.
                Expanded(
                  child: LinearProgressIndicator(
                    value: value.clamp(0.0, 1.0),
                    minHeight: HzSpace.s4,
                    borderRadius: BorderRadius.zero,
                    backgroundColor: GameColors.line,
                    color: GameColors.text,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
