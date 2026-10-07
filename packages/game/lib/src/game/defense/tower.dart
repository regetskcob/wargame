import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';

import '../../game_config.dart';
import '../components/ship_base.dart';
import '../game_phase.dart';
import '../space_game.dart';

/// A gun emplacement a player put down. It never moves and can not be
/// destroyed. Only the client of its builder aims and fires it, everybody
/// else sees the shots as they come in.
class Tower extends PositionComponent with HasGameRef<SpaceGame> {
  Tower({
    required this.ownerId,
    required this.index,
    required this.color,
    required super.position,
  }) : super(size: Vector2.all(40), anchor: Anchor.center, priority: 8);

  final String ownerId;
  final int index;
  final Color color;

  String get id => '$ownerId#$index';

  double turretAngle = 0;
  double _cooldown = 0;
  double _recoil = 0;
  double _think = 0;
  ShipBase? _target;

  bool get _mine => ownerId == gameRef.myId;

  void fired(Vector2 direction) {
    turretAngle = atan2(direction.x, -direction.y);
    _recoil = 1;
  }

  @override
  void update(double dt) {
    _recoil = max(0, _recoil - dt * 6);
    if (!_mine) {
      return;
    }
    final phase = gameRef.phase.value;
    if (phase != GamePhase.playing && phase != GamePhase.spectating) {
      return;
    }
    _cooldown -= dt;
    _think -= dt;
    if (_think <= 0) {
      _think = 0.2;
      _target = gameRef.nearestEnemy(position, GameConfig.towerRange);
    }
    final target = _target;
    if (target == null || !target.isMounted) {
      return;
    }
    final flight =
        target.position.distanceTo(position) / GameConfig.towerBulletSpeed;
    final aim = target.position + gameRef.velocityOf(target) * flight;
    final wanted = atan2(aim.x - position.x, -(aim.y - position.y));
    final diff = (wanted - turretAngle).toNormalizedAngle();
    turretAngle += diff.clamp(-6 * dt, 6 * dt);
    if (diff.abs() < 0.08 && _cooldown <= 0) {
      _cooldown = GameConfig.towerCooldown;
      gameRef.fireTower(this);
    }
  }

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    final base = Rect.fromCenter(center: c, width: 34, height: 34);
    canvas.drawRect(
      base.shift(const Offset(2, 3)),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawRect(base, Paint()..color = const Color(0xFF7A7A72));
    canvas.drawRect(
      base,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF2E2E2A),
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(turretAngle);
    final barrel = Paint()
      ..color = const Color(0xFF2E2E2A)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, 4 * _recoil),
      Offset(0, -26 + 4 * _recoil),
      barrel,
    );
    canvas.drawCircle(Offset.zero, 11, Paint()..color = color);
    canvas.drawCircle(
      Offset.zero,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = GameConfig.teamColors[1],
    );
    canvas.restore();
  }
}
