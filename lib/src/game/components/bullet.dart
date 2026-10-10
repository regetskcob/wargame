import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../game_config.dart';
import '../defense/aircraft.dart';
import '../defense/tower.dart';
import '../defense/defense_field.dart';
import '../tank_game.dart';
import 'tree.dart';
import 'drone.dart';
import 'effects.dart';
import 'obstacle.dart';
import 'soldier.dart';
import 'supply_depot.dart';

class Bullet extends PositionComponent
    with HasGameRef<TankGame>, CollisionCallbacks {
  Bullet({
    required this.bulletId,
    required this.ownerId,
    required super.position,
    required this.velocity,
    required this.color,
    required this.damage,
    this.antiAir = false,
    this.airDamage,
    this.burst = 0,
    this.small = false,
  }) : super(size: Vector2.all(6), anchor: Anchor.center, priority: 5);

  final String bulletId;
  final String ownerId;
  final Vector2 velocity;
  final Color color;
  final double damage;

  /// Fired by flak or the Habicht: brings down aircraft and drones.
  final bool antiAir;

  /// What it does to aircraft when that differs from [damage] times
  /// [GameConfig.antiAirFactor]: a flak shell hits the sky far harder than
  /// the ground.
  final double? airDamage;

  /// A flak shell's proximity fuse: it bursts this close to an aircraft or
  /// drone it may hit, see [TowerKind.burst]. 0 for every other shell.
  final double burst;

  /// A rifle bullet, drawn thinner than a shell.
  final bool small;

  double _ttl = GameConfig.bulletTtl;

  /// Seconds of flight before a shell can hit a depot.
  static const _armSeconds = 0.1;

  @override
  void onLoad() {
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    position.add(velocity * dt);
    _ttl -= dt;
    if (_ttl <= 0) {
      removeFromParent();
      return;
    }
    if (burst > 0) {
      _proximity();
    }
  }

  /// Bursts next to an aircraft or drone in reach of the fuse. Only the
  /// client that flies it takes the hit, as for a direct one.
  void _proximity() {
    // Gone from the field only at the next tick: it must not burst twice.
    if (isRemoving) {
      return;
    }
    for (final plane in gameRef.aircraft.values) {
      if (plane.isMounted &&
          plane.position.distanceTo(position) < burst &&
          plane.damageFrom(this) > 0 &&
          plane.takeHit(this)) {
        _impact(const Color(0xFF555555));
        removeFromParent();
        return;
      }
    }
    for (final drone in gameRef.drones.values) {
      if (drone.isMounted &&
          drone.position.distanceTo(position) < burst &&
          drone.shootDown(this)) {
        _impact(const Color(0xFF555555));
        removeFromParent();
        return;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final center = (size / 2).toOffset();
    if (small) {
      canvas.drawCircle(center, 1.4, Paint()..color = color);
      return;
    }
    canvas.drawCircle(center, 5, Paint()..color = color.withValues(alpha: 0.3));
    canvas.drawCircle(center, 2.5, Paint()..color = color);
  }

  @override
  void onCollisionStart(
    List<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Soldier) {
      if (other.dead ||
          other.airborne ||
          gameRef.allied(other.ownerId, ownerId)) {
        return;
      }
      if (gameRef.runsShooter(ownerId)) {
        gameRef.runOver(other, ownerId);
      }
      removeFromParent();
    } else if (other is Tower) {
      // Enemy shells wear the guns down, the defenders shoot over them.
      if (gameRef.hurtsTower(ownerId, other.ownerId)) {
        _impact(const Color(0xFF8A8A80));
        other.lastHitBy = ownerId;
        // The player who runs the waves keeps the score of every gun, also
        // of the other player's shots in a duel.
        if (gameRef.round?.botHost == gameRef.myId) {
          gameRef.damageTower(other, damage);
        }
        removeFromParent();
      }
    } else if (other is Aircraft) {
      // Aircraft only stop the shells of the other side.
      if (other.damageFrom(this) > 0 && other.takeHit(this)) {
        _impact(const Color(0xFF555555));
        removeFromParent();
      }
    } else if (other is Drone) {
      if (antiAir && other.shootDown(this)) {
        _impact(const Color(0xFF555555));
        removeFromParent();
      }
    } else if (other is Tree) {
      if (other.felled) {
        return;
      }
      _impact(const Color(0xFF6B5A3A));
      if (gameRef.runsShooter(ownerId)) {
        gameRef.damageTree(other, damage);
      }
      removeFromParent();
    } else if (other is Headquarters) {
      // Players shoot over their own base, enemy shells wear it down. The
      // player who runs the enemies keeps the score.
      if (gameRef.hurtsBase(ownerId, other.lane)) {
        gameRef.damageBase(damage, lane: other.lane);
        removeFromParent();
      }
    } else if (other is SupplyDepot) {
      // Leaving the pad, the own shell would start inside the depot: it
      // only counts once it has flown a little. A team's shells fly over
      // its own depots.
      if (other.destroyed ||
          GameConfig.bulletTtl - _ttl < _armSeconds ||
          !gameRef.hurtsDepot(ownerId, other)) {
        return;
      }
      _impact(const Color(0xFF8A7A5A));
      if (gameRef.runsShooter(ownerId)) {
        gameRef.damageDepot(other, damage, ownerId);
      }
      removeFromParent();
    } else if (other is Obstacle) {
      _impact(const Color(0xFFB8B0A0));
      // Only the shooter's client applies the damage and tells the others.
      if (gameRef.runsShooter(ownerId)) {
        gameRef.damageObstacle(other, damage);
      }
      removeFromParent();
    }
  }

  /// Sparks and a little dust where the shell struck something solid.
  void _impact(Color dust) {
    parent?.addAll([
      puff(
        position: position.clone(),
        color: const Color(0xFFFFD27A),
        count: 5,
        lifespan: 0.25,
        speed: (40, 120),
        size: (1.5, 3),
        opacity: 0.9,
      ),
      puff(
        position: position.clone(),
        color: dust,
        count: 4,
        lifespan: 0.7,
        speed: (8, 30),
        size: (3, 7),
        opacity: 0.5,
      ),
    ]);
  }

  @override
  void onRemove() {
    gameRef.bullets.remove(bulletId);
    super.onRemove();
  }
}
