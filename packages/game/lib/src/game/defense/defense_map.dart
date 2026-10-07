import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../components/tank_painter.dart';
import '../../game_config.dart';

/// The fixed battlefield of a defense round: a rectangle, one road the enemy
/// follows and the base at its end. Which of the layouts is used follows from
/// the round seed, so every client draws the same one.
class DefenseMap {
  const DefenseMap._(this.road);

  factory DefenseMap.forSeed(int seed) =>
      DefenseMap._(_layouts[(seed ~/ 4).abs() % _layouts.length]);

  static const halfWidth = 1100.0;
  static const halfHeight = 700.0;
  static const roadHalfWidth = 42.0;
  static const baseRadius = 70.0;

  static final bounds = Rect.fromLTRB(
    -halfWidth,
    -halfHeight,
    halfWidth,
    halfHeight,
  );

  static final _layouts = [
    [
      Vector2(-halfWidth, -450),
      Vector2(-620, -450),
      Vector2(-620, 400),
      Vector2(-60, 400),
      Vector2(-60, -420),
      Vector2(520, -420),
      Vector2(520, 160),
      Vector2(860, 160),
    ],
    [
      Vector2(-halfWidth, 460),
      Vector2(-720, 460),
      Vector2(-720, -440),
      Vector2(-220, -440),
      Vector2(-220, 440),
      Vector2(300, 440),
      Vector2(300, -200),
      Vector2(860, -200),
    ],
    [
      Vector2(-880, -halfHeight),
      Vector2(-880, 320),
      Vector2(-380, 320),
      Vector2(-380, -360),
      Vector2(200, -360),
      Vector2(200, 360),
      Vector2(860, 360),
      Vector2(860, 0),
    ],
  ];

  /// Waypoints from where the enemy rolls in to the base.
  final List<Vector2> road;

  Vector2 get entry => road.first;
  Vector2 get base => road.last;

  /// Shortest distance from [point] to the road's centre line.
  double distanceToRoad(Vector2 point) {
    var best = double.infinity;
    for (var i = 0; i < road.length - 1; i++) {
      best = min(best, _distanceToSegment(point, road[i], road[i + 1]));
    }
    return best;
  }

  static double _distanceToSegment(Vector2 p, Vector2 a, Vector2 b) {
    final ab = b - a;
    final length2 = ab.length2;
    if (length2 == 0) {
      return p.distanceTo(a);
    }
    final t = ((p - a).dot(ab) / length2).clamp(0.0, 1.0);
    return p.distanceTo(a + ab * t);
  }

  /// Why a gun can not go to [point], or null when it can.
  String? whyNotBuild(Vector2 point, Iterable<Vector2> towers) {
    if (!bounds.deflate(40).contains(point.toOffset())) {
      return 'Zu nah am Rand';
    }
    if (distanceToRoad(point) < roadHalfWidth + 30) {
      return 'Nicht auf der Straße';
    }
    if (point.distanceTo(base) < baseRadius + 50) {
      return 'Zu nah am Stützpunkt';
    }
    if (towers.any((t) => t.distanceTo(point) < GameConfig.towerSpacing)) {
      return 'Zu nah am nächsten Geschütz';
    }
    return null;
  }

  /// Where the players start: in a column in front of the base, off the road.
  Vector2 spawnFor(int slot, int count) {
    final spread = (slot - (count - 1) / 2) * 70;
    final candidates = [
      base + Vector2(-170, spread),
      base + Vector2(spread, -170),
      base + Vector2(spread, 170),
    ];
    for (final at in candidates) {
      if (bounds.deflate(40).contains(at.toOffset()) &&
          distanceToRoad(at) > roadHalfWidth + 20) {
        return at;
      }
    }
    return candidates.first;
  }

  /// The enemy for slot [n] of wave [wave]: more and heavier tanks later on.
  static TankType enemyType(int wave, int n) {
    final roll = (wave * 7 + n * 13) % 10;
    if (wave >= 5 && roll < 3) {
      return TankType.leopard;
    }
    if (wave >= 3 && roll < 6) {
      return TankType.gepard;
    }
    return roll.isEven ? TankType.boxer : TankType.puma;
  }

  /// Number of enemies in [wave].
  static int waveSize(int wave) => 3 + 2 * wave;
}
