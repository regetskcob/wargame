import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../game/components/tree.dart';
import '../../game/components/obstacle.dart';
import '../../game/components/storm_zone.dart';
import '../../game/defense/defense_map.dart';
import '../../game/components/soldier.dart';
import '../../game/tank_game.dart';
import '../../game/game_config.dart';
import '../theme.dart';

class MiniMap extends StatefulWidget {
  const MiniMap({required this.game, this.size = 150, super.key});

  final TankGame game;
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

  final TankGame game;

  @override
  void paint(Canvas canvas, Size size) {
    final map = game.defenseMap;
    if (map != null) {
      _paintDefense(canvas, size, map);
      return;
    }
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
    for (final rock in game.world.descendants().whereType<Tree>()) {
      if (rock.felled) {
        continue;
      }
      canvas.drawCircle(
        toMap(rock.position.x, rock.position.y),
        (rock.radius * scale).clamp(1.0, 6.0),
        rockPaint,
      );
    }

    final soldierPaint = Paint()..color = const Color(0xFFD9C97A);
    for (final soldier in game.soldierField?.all ?? const <Soldier>[]) {
      if (!soldier.dead && soldier.isMounted) {
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
      final c = toMap(crate.position.x, crate.position.y);
      final paint = Paint()..color = crate.type.color;
      if (crate.type.gem) {
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - 4)
            ..lineTo(c.dx + 3.5, c.dy)
            ..lineTo(c.dx, c.dy + 4)
            ..lineTo(c.dx - 3.5, c.dy)
            ..close(),
          paint,
        );
      } else {
        canvas.drawRect(Rect.fromCenter(center: c, width: 5, height: 5), paint);
      }
    }
    for (final drone in game.drones.values) {
      canvas.drawCircle(
        toMap(drone.position.x, drone.position.y),
        2,
        Paint()..color = const Color(0xFFFF3D00),
      );
    }

    for (final tank in [...game.remoteTanks.values, ...game.botTanks.values]) {
      if (tank.hidden || !game.canSee(tank.position)) {
        continue;
      }
      canvas.drawCircle(
        toMap(tank.position.x, tank.position.y),
        2.5,
        Paint()
          ..color = tank.team > 0
              ? GameConfig.teamColors[tank.team]
              : tank.tankColor,
      );
    }
    final me = game.myTank;
    if (me != null && me.isMounted) {
      final p = toMap(me.position.x, me.position.y);
      final forward = Offset(sin(me.turretAngle), -cos(me.turretAngle));
      canvas.drawLine(
        p,
        p + forward * 13,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(p, 5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 3, Paint()..color = me.tankColor);
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

  /// The rectangle of a defense round with its road, the base and the guns.
  void _paintDefense(Canvas canvas, Size size, DefenseMap map) {
    final scale = size.width / (2 * DefenseMap.halfWidth);
    final height = 2 * DefenseMap.halfHeight * scale;
    final frame = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width,
      height: height,
    );
    Offset toMap(double x, double y) => frame.center + Offset(x, y) * scale;

    canvas.drawRect(frame, Paint()..color = BwColors.panel);
    final river = Path()
      ..moveTo(
        toMap(map.river.first.x, map.river.first.y).dx,
        toMap(map.river.first.x, map.river.first.y).dy,
      );
    for (final point in map.river.skip(1)) {
      final p = toMap(point.x, point.y);
      river.lineTo(p.dx, p.dy);
    }
    canvas.save();
    canvas.clipRect(frame);
    canvas.drawPath(
      river,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(2.0, DefenseMap.riverHalfWidth * 2 * scale)
        ..color = const Color(0xAA3B7194),
    );
    canvas.restore();
    final road = Path();
    for (final line in map.roads) {
      final start = toMap(line.first.x, line.first.y);
      road.moveTo(start.dx, start.dy);
      for (final point in line.skip(1)) {
        final p = toMap(point.x, point.y);
        road.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      road,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(2.0, DefenseMap.roadHalfWidth * 2 * scale)
        ..color = BwColors.sand.withValues(alpha: 0.5),
    );
    // A duel's bases in the colour of their side.
    for (final (lane, base) in map.bases.indexed) {
      canvas.drawCircle(
        toMap(base.x, base.y),
        max(3.0, DefenseMap.baseRadius * scale),
        Paint()..color = GameConfig.teamColors[lane + 1],
      );
    }
    // The enemy's outpost at the start of the road, in a duel the other
    // side's base.
    if (!map.duel) {
      canvas.drawRect(
        Rect.fromCenter(
          center: toMap(map.outpost.x, map.outpost.y),
          width: 6,
          height: 6,
        ),
        Paint()..color = GameConfig.teamColors[2],
      );
    }
    for (final bridge in map.bridges) {
      canvas.drawCircle(
        toMap(bridge.centre.x, bridge.centre.y),
        2.5,
        Paint()..color = const Color(0xFF7A5C3A),
      );
    }
    final soldierPaint = Paint()..color = GameConfig.teamColors[2];
    for (final soldier in game.soldierField?.all ?? const <Soldier>[]) {
      if (!soldier.dead && soldier.isMounted) {
        canvas.drawCircle(
          toMap(soldier.position.x, soldier.position.y),
          1.3,
          soldier.ownerId != null &&
                  game.round?.isEnemy(soldier.ownerId!) == true
              ? soldierPaint
              : (Paint()..color = const Color(0xFFD9C97A)),
        );
      }
    }
    for (final plane in game.aircraft.values) {
      final p = toMap(plane.position.x, plane.position.y);
      canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy - 4)
          ..lineTo(p.dx + 3.5, p.dy + 3)
          ..lineTo(p.dx - 3.5, p.dy + 3)
          ..close(),
        Paint()
          ..color = plane.friendly
              ? const Color(0xFF9CCC65)
              : const Color(0xFFFF5252),
      );
    }
    for (final drone in game.drones.values) {
      canvas.drawCircle(
        toMap(drone.position.x, drone.position.y),
        1.6,
        Paint()..color = const Color(0xFFFF3D00),
      );
    }
    for (final crate in game.powerUps.values) {
      canvas.drawCircle(
        toMap(crate.position.x, crate.position.y),
        1.8,
        Paint()..color = crate.type.color,
      );
    }
    for (final tower in game.towers.values) {
      final at = Rect.fromCenter(
        center: toMap(tower.position.x, tower.position.y),
        width: 6,
        height: 6,
      );
      canvas.drawRect(at.inflate(1), Paint()..color = Colors.black);
      canvas.drawRect(at, Paint()..color = tower.color);
    }
    for (final tank in [...game.remoteTanks.values, ...game.botTanks.values]) {
      canvas.drawCircle(
        toMap(tank.position.x, tank.position.y),
        2.5,
        Paint()..color = GameConfig.teamColors[tank.team],
      );
    }
    final me = game.myTank;
    if (me != null && me.isMounted) {
      final p = toMap(me.position.x, me.position.y);
      canvas.drawCircle(p, 4.5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 2.8, Paint()..color = me.tankColor);
    }
    canvas.drawRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = BwColors.oliveLight,
    );
  }

  @override
  bool shouldRepaint(_MiniMapPainter old) => true;
}
