import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../game_config.dart';
import '../space_game.dart';
import 'asteroid.dart';
import 'obstacle.dart';

class Bullet extends PositionComponent
    with HasGameRef<SpaceGame>, CollisionCallbacks {
  Bullet({
    required this.bulletId,
    required this.ownerId,
    required super.position,
    required this.velocity,
    required this.color,
    required this.damage,
  }) : super(size: Vector2.all(6), anchor: Anchor.center, priority: 5);

  final String bulletId;
  final String ownerId;
  final Vector2 velocity;
  final Color color;
  final double damage;

  double _ttl = GameConfig.bulletTtl;

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
    }
  }

  @override
  void render(Canvas canvas) {
    final center = (size / 2).toOffset();
    canvas.drawCircle(center, 5, Paint()..color = color.withValues(alpha: 0.3));
    canvas.drawCircle(center, 2.5, Paint()..color = color);
  }

  @override
  void onCollisionStart(
    List<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Asteroid) {
      removeFromParent();
    } else if (other is Obstacle) {
      // Only the shooter's client applies the damage and tells the others.
      if (ownerId == gameRef.myId) {
        gameRef.damageObstacle(other, damage);
      }
      removeFromParent();
    }
  }

  @override
  void onRemove() {
    gameRef.bullets.remove(bulletId);
    super.onRemove();
  }
}
