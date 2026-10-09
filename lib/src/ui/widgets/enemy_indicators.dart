import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../game/components/tank_base.dart';
import '../../game/game_phase.dart';
import '../../game/tank_game.dart';
import '../../game/game_config.dart';
import '../theme.dart';

/// Arrows on the edge of the view that point at enemy tanks which are off
/// screen, with the distance next to each.
class EnemyIndicators extends StatefulWidget {
  const EnemyIndicators({required this.game, super.key});

  final TankGame game;

  @override
  State<EnemyIndicators> createState() => _EnemyIndicatorsState();
}

class _EnemyIndicatorsState extends State<EnemyIndicators>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => setState(() {}))..start();

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: CustomPaint(painter: _IndicatorPainter(widget.game)),
      ),
    );
  }
}

class _IndicatorPainter extends CustomPainter {
  _IndicatorPainter(this.game);

  final TankGame game;

  @override
  void paint(Canvas canvas, Size size) {
    final me = game.myTank;
    if (game.phase.value != GamePhase.playing || me == null) {
      return;
    }
    final scale = game.viewScale;
    final view = Offset.zero & size;
    final centre = view.center;
    final inner = view.deflate(30);
    final camera = game.camera.viewfinder.position;

    final enemies =
        <TankBase>[...game.remoteTanks.values, ...game.botTanks.values]
            .where(
              (tank) =>
                  tank.isMounted &&
                  !tank.hidden &&
                  game.canSee(tank.position) &&
                  !game.sameTeam(me.playerId, tank.playerId),
            )
            .toList()
          ..sort(
            (a, b) => a.position
                .distanceTo(me.position)
                .compareTo(b.position.distanceTo(me.position)),
          );

    // Capture the flag: where both flags are, beyond the edge.
    final flags = game.flagMatch;
    if (flags != null) {
      for (final flag in flags.flags.values) {
        final carrier = flag.carrier;
        final at = carrier == null
            ? flag.position
            : game.tankById(carrier)?.position ?? flag.position;
        if (carrier == me.playerId) {
          continue;
        }
        final screen =
            centre +
            Offset((at.x - camera.x) * scale, (at.y - camera.y) * scale);
        if (inner.contains(screen)) {
          continue;
        }
        final direction = screen - centre;
        final tx = direction.dx == 0
            ? double.infinity
            : (inner.width / 2) / direction.dx.abs();
        final ty = direction.dy == 0
            ? double.infinity
            : (inner.height / 2) / direction.dy.abs();
        final edge = centre + direction * min(tx, ty) * 0.9;
        _flagMarker(canvas, edge, GameConfig.teamColors[flag.team]);
      }
    }

    for (final tank in enemies.take(6)) {
      final screen =
          centre +
          Offset(
            (tank.position.x - camera.x) * scale,
            (tank.position.y - camera.y) * scale,
          );
      if (inner.contains(screen)) {
        continue;
      }
      final direction = screen - centre;
      final tx = direction.dx == 0
          ? double.infinity
          : (inner.width / 2) / direction.dx.abs();
      final ty = direction.dy == 0
          ? double.infinity
          : (inner.height / 2) / direction.dy.abs();
      final at = centre + direction * min(tx, ty);
      final angle = atan2(direction.dy, direction.dx);
      final distance = tank.position.distanceTo(me.position);
      final near = distance < 450;
      final color = tank.team > 0
          ? GameConfig.teamColors[tank.team]
          : BwColors.danger;

      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(angle);
      final arrow = Path()
        ..moveTo(16, 0)
        ..lineTo(-9, -11)
        ..lineTo(-4, 0)
        ..lineTo(-9, 11)
        ..close();
      canvas.drawPath(arrow, Paint()..color = const Color(0x88000000));
      canvas.drawPath(
        arrow.shift(const Offset(-1, 0)),
        Paint()..color = color.withValues(alpha: near ? 1 : 0.75),
      );
      canvas.restore();

      final label = TextPainter(
        text: TextSpan(
          text: '${(distance / 10).round()} m',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // The label sits on the side of the arrow that faces the middle.
      final inward = Offset(-cos(angle), -sin(angle)) * 26;
      label.paint(
        canvas,
        at + inward - Offset(label.width / 2, label.height / 2),
      );
    }
  }

  /// A small flag on the edge of the view, where a flag lies beyond it.
  void _flagMarker(Canvas canvas, Offset at, Color color) {
    canvas.drawCircle(at, 13, Paint()..color = const Color(0x99000000));
    canvas.drawLine(
      at + const Offset(-4, 8),
      at + const Offset(-4, -8),
      Paint()
        ..strokeWidth = 2
        ..color = Colors.white,
    );
    canvas.drawPath(
      Path()
        ..moveTo(at.dx - 4, at.dy - 8)
        ..lineTo(at.dx + 8, at.dy - 4)
        ..lineTo(at.dx - 4, at.dy)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_IndicatorPainter old) => true;
}
