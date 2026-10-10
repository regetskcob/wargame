import 'dart:math';

import 'package:clock/clock.dart';
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

  /// Faster than any tank drives, boosts included.
  static const maxRemoteSpeed = 900.0;

  static double _speed(double value) => value.isFinite
      ? value.clamp(-maxRemoteSpeed, maxRemoteSpeed).toDouble()
      : 0;
  late double _targetAngle;

  /// When the last state arrived, to notice tanks that went silent.
  DateTime lastSeen = clock.now();
  late double _targetTurret = turretAngle;

  void applyState(TankStatePayload state) {
    lastSeen = clock.now();
    _target.setValues(state.x, state.y);
    // Anybody can send a state: a speed of 1e308 would carry the tank to
    // infinity and then to NaN for good, an angle of NaN would do the same
    // to its drawing. Speeds are capped well above any tank's.
    velocity.setValues(_speed(state.vx), _speed(state.vy));
    if (velocity.length > maxRemoteSpeed) {
      velocity.scaleTo(maxRemoteSpeed);
    }
    if (state.rotation.isFinite) {
      _targetAngle = state.rotation;
    }
    final turret = state.turret ?? state.rotation;
    if (turret.isFinite) {
      _targetTurret = turret;
    }
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
