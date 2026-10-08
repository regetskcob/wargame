import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';

import '../components/player_tank.dart';
import '../game_phase.dart';
import '../tank_game.dart';
import '../touch_input.dart';
import 'defense_map.dart';

/// Drives an enemy tank of a defense round along the road to the base. It
/// shoots at the defenders' tanks and guns near the way and rams the base at
/// the end.
class DefenseBrain extends Component with HasGameRef<TankGame> {
  DefenseBrain({
    required this.tank,
    required this.controls,
    required this.map,
    this.lane = 0,
  });

  final PlayerTank tank;
  final TouchInput controls;

  /// The road it follows and the base at its end: in a duel the [lane] of
  /// the side it attacks.
  final DefenseMap map;
  final int lane;

  final _random = Random();
  int _next = 1;
  double _think = 0;
  double _fireGate = 0;
  double _aimError = 0;
  PositionComponent? _target;

  @override
  void update(double dt) {
    if (!tank.isMounted) {
      removeFromParent();
      return;
    }
    final phase = gameRef.phase.value;
    if (phase != GamePhase.playing && phase != GamePhase.spectating) {
      controls.reset();
      return;
    }
    if (tank.position.distanceTo(map.base) < DefenseMap.baseRadius + 10) {
      gameRef.raidBase(tank, lane: lane);
      return;
    }
    _think -= dt;
    if (_think <= 0) {
      _think = 0.25;
      _aimError = (_random.nextDouble() * 2 - 1) * 0.15;
      // Tanks first, else the guns and trenches along the way.
      _target =
          gameRef.nearestDefender(tank.position, 360, of: tank.playerId) ??
          gameRef.nearestTower(tank.position, 320, of: tank.playerId);
    }
    _drive();
    _shoot(dt);
  }

  double _headingTo(Vector2 point) =>
      atan2(point.x - tank.position.x, -(point.y - tank.position.y));

  /// Follows a point a little ahead on the road, so the tank keeps to it
  /// through the bends instead of circling a corner it overshot.
  void _drive() {
    final road = map.road;
    while (_next < road.length - 1) {
      final a = road[_next - 1];
      final b = road[_next];
      final passed = (tank.position - b).dot(b - a) > 0;
      if (!passed && tank.position.distanceTo(b) > 60) {
        break;
      }
      _next++;
    }
    final a = road[_next - 1];
    final b = road[_next];
    final along = b - a;
    final length = along.length;
    final dir = length == 0 ? Vector2.zero() : along / length;
    final t = (tank.position - a).dot(dir).clamp(0.0, length);
    var ahead = 100.0;
    final left = length - t;
    final Vector2 goal;
    if (ahead <= left || _next == road.length - 1) {
      goal = a + dir * min(length, t + ahead);
    } else {
      ahead -= left;
      final next = road[_next + 1] - b;
      goal = b + next.normalized() * min(ahead, next.length);
    }
    final heading = _headingTo(goal);
    final diff = (heading - tank.angle).toNormalizedAngle();
    controls
      ..left = diff < -0.06
      ..right = diff > 0.06
      // Off the gas in a bend and on the brakes in a sharp one, so even
      // the quick wheeled tanks make the corner.
      ..thrust = diff.abs() < 0.2
      ..brake = diff.abs() > 0.45 && tank.velocity.length > 40;
  }

  void _shoot(double dt) {
    final target = _target;
    final Vector2 aimAt;
    if (target != null && target.isMounted) {
      aimAt = target.position;
    } else if (tank.position.distanceTo(map.base) < 380) {
      aimAt = map.base;
    } else {
      controls
        ..aim = null
        ..fire = false;
      _fireGate = 0;
      return;
    }
    controls.aim = _headingTo(aimAt) + _aimError;
    final onTarget =
        (controls.aim! - tank.turretAngle).toNormalizedAngle().abs() < 0.15;
    _fireGate = onTarget ? _fireGate + dt : 0;
    controls.fire = _fireGate > 0.5;
  }
}
