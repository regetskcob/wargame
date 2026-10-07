import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';

import '../../game_config.dart';
import '../../net/net_events.dart';
import '../../net/payloads/special_payload.dart';
import '../space_game.dart';
import '../special_weapon.dart';
import 'ship_base.dart';

/// A kamikaze quadcopter. It flies over walls and trees, homes in on the
/// nearest enemy and blows up next to it, or wherever it is when the battery
/// runs out.
///
/// Only the client of the tank that launched it steers it and tells the
/// others where it is. On every other client the same component just follows
/// those messages.
class Drone extends PositionComponent with HasGameRef<SpaceGame> {
  Drone({
    required this.droneId,
    required this.ownerId,
    required this.color,
    required Vector2 position,
    required double angle,
    this.remote = false,
  }) : _target = position.clone(),
       _targetAngle = angle,
       super(position: position, angle: angle, priority: 22);

  final String droneId;
  final String ownerId;
  final Color color;
  final bool remote;

  final Vector2 _target;
  double _targetAngle;
  double _age = 0;
  double _sinceSync = 0;
  double _sinceSeen = 0;

  Vector2 get _heading => Vector2(sin(angle), -cos(angle));

  void applyState(DronePayload state) {
    _sinceSeen = 0;
    _target.setValues(state.x, state.y);
    _targetAngle = state.angle;
  }

  @override
  void update(double dt) {
    _age += dt;
    if (remote) {
      _follow(dt);
    } else {
      _fly(dt);
    }
  }

  void _follow(double dt) {
    _sinceSeen += dt;
    // The owner left or the blast message got lost.
    if (_sinceSeen > 2) {
      removeFromParent();
      return;
    }
    position.add(_heading * GameConfig.droneSpeed * dt);
    _target.add(_heading * GameConfig.droneSpeed * dt);
    final factor = min(1.0, dt * GameConfig.remoteLerpFactorPerSecond);
    position.add((_target - position) * factor);
    angle += (_targetAngle - angle).toNormalizedAngle() * factor;
  }

  void _fly(double dt) {
    ShipBase? prey;
    var best = double.infinity;
    for (final enemy in gameRef.enemiesOf(ownerId)) {
      final distance = enemy.position.distanceTo(position);
      if (distance < best) {
        best = distance;
        prey = enemy;
      }
    }
    if (prey != null) {
      final wanted = atan2(
        prey.position.x - position.x,
        -(prey.position.y - position.y),
      );
      final diff = (wanted - angle).toNormalizedAngle();
      final step = GameConfig.droneTurnRate * dt;
      angle += diff.clamp(-step, step);
    }
    position.add(_heading * GameConfig.droneSpeed * dt);
    if (position.length > GameConfig.worldRadius) {
      position.scaleTo(GameConfig.worldRadius);
    }
    if (best <= GameConfig.droneTrigger || _age >= GameConfig.droneSeconds) {
      gameRef.detonate(
        ownerId: ownerId,
        blastId: droneId,
        at: position.clone(),
        weapon: SpecialWeapon.drone,
        announce: true,
      );
      removeFromParent();
      return;
    }
    _sinceSync += dt;
    if (_sinceSync >= GameConfig.droneSyncInterval) {
      _sinceSync = 0;
      gameRef.net.send(
        NetEvent.drone,
        DronePayload(
          id: ownerId,
          droneId: droneId,
          x: position.x,
          y: position.y,
          angle: angle,
        ).toJson(),
      );
    }
  }

  @override
  void onRemove() {
    gameRef.drones.remove(droneId);
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    // Shadow on the ground below and behind it.
    canvas.drawCircle(
      const Offset(7, 11),
      11,
      Paint()..color = const Color(0x40000000),
    );
    canvas.save();
    canvas.rotate(angle);
    final arm = Paint()
      ..color = const Color(0xFF2B2E26)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const reach = 10.0;
    for (final d in const [
      (-1.0, -1.0),
      (1.0, -1.0),
      (-1.0, 1.0),
      (1.0, 1.0),
    ]) {
      final tip = Offset(d.$1 * reach, d.$2 * reach);
      canvas.drawLine(Offset.zero, tip, arm);
      canvas.drawCircle(tip, 6, Paint()..color = const Color(0x55E6E2D3));
      // Spinning blade, a line that turns fast.
      final spin = _age * 40 + d.$1 * 2 + d.$2;
      canvas.drawLine(
        tip + Offset(cos(spin) * 6, sin(spin) * 6),
        tip - Offset(cos(spin) * 6, sin(spin) * 6),
        Paint()
          ..color = const Color(0xAA1A1A1A)
          ..strokeWidth = 1.5,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 9, height: 12),
        const Radius.circular(3),
      ),
      Paint()..color = color,
    );
    // Warhead at the front and a blinking light.
    canvas.drawCircle(
      const Offset(0, -6),
      2.6,
      Paint()..color = const Color(0xFF3A3A32),
    );
    if ((_age * 4).floor().isEven) {
      canvas.drawCircle(
        const Offset(0, 3),
        1.8,
        Paint()..color = const Color(0xFFFF3D00),
      );
    }
    canvas.restore();
  }
}
