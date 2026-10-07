import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../game/components/asteroid.dart';
import '../../game/components/obstacle.dart';
import '../../game/components/storm_zone.dart';
import '../../game/space_game.dart';
import '../../game_config.dart';
import '../../theme.dart';

class MiniMap extends StatefulWidget {
  const MiniMap({required this.game, this.size = 150, super.key});

  final SpaceGame game;
  final double size;

  @override
  State<MiniMap> createState() => _MiniMapState();
}

class _MiniMapState extends State<MiniMap> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => setState(() {}))..start();

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(painter: _MiniMapPainter(widget.game)),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter(this.game);

  final SpaceGame game;

  @override
  void paint(Canvas canvas, Size size) {
    final round = game.round;
    final center = size.center(Offset.zero);
    final scale = size.width / 2 / GameConfig.worldRadius;
    Offset toMap(double x, double y) => center + Offset(x, y) * scale;

    canvas.drawCircle(center, size.width / 2, Paint()..color = BwColors.panel);
    if (round == null) {
      return;
    }

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: size.width / 2)),
    );

    final safeRadius = StormZone.radiusAt(
      round.startedAt,
      DateTime.now().millisecondsSinceEpoch,
    );
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addOval(Rect.fromCircle(center: center, radius: safeRadius * scale)),
      Paint()..color = const Color(0x44B8860B),
    );
    canvas.drawCircle(
      center,
      safeRadius * scale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xCCFFB300),
    );

    final mud = game.mudField;
    if (mud != null) {
      final mudPaint = Paint()..color = mud.theme.mud.withValues(alpha: 0.7);
      for (final patch in mud.patches) {
        canvas.drawCircle(
          toMap(patch.centre.x, patch.centre.y),
          patch.radius * scale,
          mudPaint,
        );
      }
    }

    final rockPaint = Paint()..color = BwColors.textDim;
    for (final rock in game.world.descendants().whereType<Asteroid>()) {
      canvas.drawCircle(
        toMap(rock.position.x, rock.position.y),
        (rock.radius * scale).clamp(1.0, 6.0),
        rockPaint,
      );
    }

    final soldierPaint = Paint()..color = const Color(0xFFD9C97A);
    for (final soldier in game.soldierField?.soldiers ?? const []) {
      if (!soldier.dead) {
        canvas.drawCircle(
          toMap(soldier.position.x, soldier.position.y),
          1.2,
          soldierPaint,
        );
      }
    }

    final solidPaint = Paint()..color = BwColors.sand;
    for (final solid in game.world.descendants().whereType<Obstacle>()) {
      final c = toMap(solid.position.x, solid.position.y);
      final w = (solid.size.x * scale).clamp(2.0, 9.0);
      final h = (solid.size.y * scale).clamp(2.0, 9.0);
      canvas.drawRect(
        Rect.fromCenter(center: c, width: w, height: h),
        solidPaint,
      );
    }

    for (final cloud in game.smokes) {
      canvas.drawCircle(
        toMap(cloud.position.x, cloud.position.y),
        GameConfig.smokeRadius * scale,
        Paint()..color = const Color(0x88B0BEC5),
      );
    }
    for (final crate in game.powerUps.values) {
      canvas.drawRect(
        Rect.fromCenter(
          center: toMap(crate.position.x, crate.position.y),
          width: 5,
          height: 5,
        ),
        Paint()..color = crate.type.color,
      );
    }

    for (final ship in [...game.remoteShips.values, ...game.botShips.values]) {
      if (ship.hidden) {
        continue;
      }
      canvas.drawCircle(
        toMap(ship.position.x, ship.position.y),
        2.5,
        Paint()
          ..color = ship.team > 0
              ? GameConfig.teamColors[ship.team]
              : ship.shipColor,
      );
    }
    final me = game.myShip;
    if (me != null && me.isMounted) {
      final p = toMap(me.position.x, me.position.y);
      canvas.drawCircle(p, 5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 3, Paint()..color = me.shipColor);
    }
    canvas.restore();

    canvas.drawCircle(
      center,
      size.width / 2 - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = BwColors.oliveLight,
    );
  }

  @override
  bool shouldRepaint(_MiniMapPainter old) => true;
}
