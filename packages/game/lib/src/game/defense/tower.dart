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
  }) : super(size: Vector2.all(72), anchor: Anchor.center, priority: 8);

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
    // Faint ring of how far the gun reaches, so the field shows at a glance
    // which stretch of the road is covered.
    canvas.drawCircle(
      c,
      GameConfig.towerRange,
      Paint()..color = color.withValues(alpha: 0.05),
    );
    canvas.drawCircle(
      c,
      GameConfig.towerRange,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: _mine ? 0.35 : 0.2),
    );
    // Sandbagged pit in the colour of the builder, bright enough to stand
    // out from the ground from far up.
    canvas.drawCircle(
      c + const Offset(3, 4),
      30,
      Paint()..color = const Color(0x66000000),
    );
    canvas.drawCircle(c, 30, Paint()..color = const Color(0xFFB59B6B));
    canvas.drawCircle(
      c,
      30,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = color,
    );
    canvas.drawCircle(
      c,
      33,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF101010),
    );
    final pad = Rect.fromCenter(center: c, width: 34, height: 34);
    canvas.drawRect(pad, Paint()..color = const Color(0xFF55574F));
    canvas.drawRect(
      pad,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF1E1E1C),
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(turretAngle);
    final recoil = 6 * _recoil;
    canvas.drawLine(
      Offset(-5, recoil),
      Offset(-5, -40 + recoil),
      Paint()
        ..color = const Color(0xFF1E1E1C)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(5, recoil),
      Offset(5, -40 + recoil),
      Paint()
        ..color = const Color(0xFF1E1E1C)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    if (_recoil > 0.6) {
      canvas.drawCircle(
        const Offset(0, -46),
        9,
        Paint()..color = const Color(0xCCFFD27A),
      );
    }
    canvas.drawCircle(Offset.zero, 15, Paint()..color = color);
    canvas.drawCircle(
      Offset.zero,
      15,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF101010),
    );
    canvas.restore();
  }
}
