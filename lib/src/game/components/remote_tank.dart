import 'dart:math';

import 'package:flame/extensions.dart';

import '../game_config.dart';
import '../../net/payloads/tank_state_payload.dart';
import 'tank_base.dart';

class RemoteTank extends TankBase {
  RemoteTank({
    required super.playerId,
    required super.playerName,
    required super.tankColor,
    required super.tankType,
    required Vector2 position,
    super.angle,
  }) : _target = position.clone(),
       super(position: position) {
    _targetAngle = angle;
  }

  final Vector2 _target;
  final velocity = Vector2.zero();
  late double _targetAngle;

  /// When the last state arrived, to notice tanks that went silent.
  DateTime lastSeen = DateTime.now();
  late double _targetTurret = turretAngle;

  void applyState(TankStatePayload state) {
    lastSeen = DateTime.now();
    _target.setValues(state.x, state.y);
    velocity.setValues(state.vx, state.vy);
    _targetAngle = state.rotation;
    _targetTurret = state.turret ?? state.rotation;
    hp = state.hp;
    shielded = state.shielded;
    if (position.distanceTo(_target) > GameConfig.remoteTeleportDistance) {
      position.setFrom(_target);
      angle = _targetAngle;
      turretAngle = _targetTurret;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _target.add(velocity * dt);
    position.add(velocity * dt);
    final factor = min(1.0, dt * GameConfig.remoteLerpFactorPerSecond);
    position.add((_target - position) * factor);
    angle += (_targetAngle - angle).toNormalizedAngle() * factor;
    turretAngle += (_targetTurret - turretAngle).toNormalizedAngle() * factor;
  }
}
