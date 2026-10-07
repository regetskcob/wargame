import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/services.dart';

import '../../audio_service.dart';
import '../../game_config.dart';
import '../../net/net_events.dart';
import '../../net/payloads/hit_payload.dart';
import '../../net/payloads/ship_state_payload.dart';
import '../defense/defense_map.dart';
import '../game_phase.dart';
import '../special_weapon.dart';
import '../touch_input.dart';
import '../space_game.dart';
import 'asteroid.dart';
import 'obstacle.dart';
import 'soldier.dart';
import 'bullet.dart';
import 'power_up.dart';
import 'ship_base.dart';
import 'storm_zone.dart';

class PlayerShip extends ShipBase
    with HasGameRef<SpaceGame>, KeyboardHandler, CollisionCallbacks {
  PlayerShip({
    required super.playerId,
    required super.playerName,
    required super.shipColor,
    required super.tankType,
    required super.position,
    super.angle,
    this.controls,
  });

  /// Set for computer controlled tanks, which steer through it instead of
  /// the keyboard and the touch controls.
  final TouchInput? controls;

  bool get isBot => controls != null;

  TouchInput get input => controls ?? gameRef.touch;

  final velocity = Vector2.zero();
  double _speed = 0;

  /// Enemies of a defense round drive slower, shoot less often and report
  /// their state less often than a player's tank.
  double speedFactor = 1;
  double fireFactor = 1;
  double syncInterval = GameConfig.stateSyncInterval;

  /// Enemies of a defense round never run dry, there are no gems for them.
  bool endlessAmmo = false;
  double rapidFireLeft = 0;

  /// Rounds left in the magazine. Gems put more back.
  late int ammo = stats.ammo;

  /// Special weapon from a gem and the charges it has left.
  SpecialWeapon? special;
  int specialCharges = 0;
  double _specialCooldown = 0;

  /// Forward speed as a share of this tank's top speed, below 0 in reverse.
  double get load => _speed / (GameConfig.shipMaxSpeed * stats.speed);

  bool _thrust = false;
  bool _brake = false;
  bool _left = false;
  bool _right = false;
  bool _fire = false;
  bool _special = false;
  bool _turretLeft = false;
  bool _turretRight = false;
  bool _aimed = false;
  int _treeContacts = 0;

  double _fireCooldown = 0;
  double _sinceSync = 0;
  double _sinceSend = 0;
  final _lastSentPosition = Vector2.zero();
  double _lastSentAngle = 0;
  double _lastSentTurret = 0;

  @override
  void onLoad() {
    super.onLoad();
    add(CircleHitbox());
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (isBot) {
      return true;
    }
    _thrust =
        keysPressed.contains(LogicalKeyboardKey.arrowUp) ||
        keysPressed.contains(LogicalKeyboardKey.keyW);
    _brake =
        keysPressed.contains(LogicalKeyboardKey.arrowDown) ||
        keysPressed.contains(LogicalKeyboardKey.keyS);
    _left =
        keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA);
    _right =
        keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD);
    _fire = keysPressed.contains(LogicalKeyboardKey.space);
    _special = keysPressed.contains(LogicalKeyboardKey.keyF);
    _turretLeft = keysPressed.contains(LogicalKeyboardKey.keyQ);
    _turretRight = keysPressed.contains(LogicalKeyboardKey.keyE);
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyB) {
      gameRef.buildTower();
    }
    return true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final phase = gameRef.phase.value;
    // Bots keep fighting while their host spectates after losing.
    if (phase != GamePhase.playing &&
        !(isBot && phase == GamePhase.spectating)) {
      return;
    }
    _integrate(dt);
    _aim(dt);
    _applyZoneDamage(dt);
    _handleFire(dt);
    _handleSpecial(dt);
    _broadcastState(dt);
  }

  /// Tracks drive along the hull, so the tank never slides sideways: the
  /// velocity vector is always derived from the heading and [_speed].
  void _integrate(double dt) {
    final thrusting = _thrust || input.thrust;
    final braking = _brake || input.brake;
    var turn =
        ((_right || input.right) ? 1 : 0) - ((_left || input.left) ? 1 : 0);
    // Steering follows the direction of travel: in reverse, left swings the
    // rear to the left like a car would. Bots steer by heading, so not them.
    final reversing = _speed < 0 || (_speed == 0 && braking && !thrusting);
    if (reversing && !isBot) {
      turn = -turn;
    }
    // Woods drag the tank down to about half its speed, soft ground to 60 %.
    final soft = gameRef.mudField?.softAt(position) ?? false;
    final maxSpeed =
        GameConfig.shipMaxSpeed *
        stats.speed *
        speedFactor *
        min(_treeContacts > 0 ? 0.55 : 1.0, soft ? 0.6 : 1.0);
    final acceleration = GameConfig.shipAcceleration * stats.acceleration;
    // Tracks turn slower at full speed, and almost on the spot when standing.
    final turnScale = 1 - 0.35 * (_speed.abs() / maxSpeed);
    angle +=
        turn * GameConfig.shipRotationSpeed * stats.turnRate * turnScale * dt;

    if (thrusting) {
      _speed += (_speed < 0 ? GameConfig.shipBrake : acceleration) * dt;
    } else if (braking) {
      _speed -= (_speed > 0 ? GameConfig.shipBrake : acceleration) * dt;
    } else {
      final decel = GameConfig.shipRollingResistance * dt;
      _speed = _speed.abs() <= decel ? 0 : _speed - decel * _speed.sign;
    }
    // Ease down to a lower limit instead of snapping to it.
    if (_speed > maxSpeed) {
      _speed = max(maxSpeed, _speed - 600 * dt);
    }
    _speed = _speed.clamp(-GameConfig.shipReverseSpeed, maxSpeed);

    velocity
      ..setFrom(direction)
      ..scale(_speed);
    position.add(velocity * dt);
    if (gameRef.defenseMap != null) {
      final bounds = DefenseMap.bounds;
      final x = position.x.clamp(bounds.left, bounds.right);
      final y = position.y.clamp(bounds.top, bounds.bottom);
      if (x != position.x || y != position.y) {
        position.setValues(x, y);
        _speed *= 0.4;
      }
    } else if (position.length > GameConfig.worldRadius) {
      position.scaleTo(GameConfig.worldRadius);
      _speed *= 0.4;
    }
  }

  /// The turret turns on its own: with the mouse, the aim stick or Q and E.
  /// Until one of them is used it simply follows the hull.
  void _aim(double dt) {
    const turretSpeed = 10.0;
    final keys = (_turretRight ? 1 : 0) - (_turretLeft ? 1 : 0);
    double? target;
    final stick = input.aim;
    if (stick != null) {
      target = stick;
    } else if (!isBot) {
      final point = gameRef.pointerWorld();
      // Inside the hull the angle to the cursor flips wildly: hold still.
      if (point != null && point.distanceTo(position) > 30) {
        target = atan2(point.x - position.x, -(point.y - position.y));
      }
    }
    if (keys != 0) {
      _aimed = true;
      turretAngle += keys * 3 * dt;
    } else if (target != null) {
      _aimed = true;
      final diff = (target - turretAngle).toNormalizedAngle();
      turretAngle += diff.abs() < 0.02
          ? diff
          : diff.clamp(-turretSpeed * dt, turretSpeed * dt);
    } else if (!_aimed) {
      turretAngle = angle;
    }
  }

  void _applyZoneDamage(double dt) {
    final round = gameRef.round;
    if (round == null || round.defense) {
      return;
    }
    final radius = StormZone.radiusAt(
      round.startedAt,
      DateTime.now().millisecondsSinceEpoch,
    );
    if (position.length > radius) {
      applyDamage(GameConfig.zoneDamagePerSecond * dt, killerId: null);
    }
  }

  void _handleFire(double dt) {
    _fireCooldown -= dt;
    if (rapidFireLeft > 0) {
      rapidFireLeft = max(0, rapidFireLeft - dt);
      if (!isBot) {
        gameRef.rapidFireSeconds.value = rapidFireLeft.ceil();
      }
    }
    if ((_fire || input.fire || input.aimFire) && _fireCooldown <= 0) {
      if (ammo <= 0 && !endlessAmmo) {
        // Dry click, and a reminder that the magazine is empty.
        _fireCooldown = 0.5;
        if (!isBot) {
          AudioService.play('tick', volume: 0.6);
          gameRef.showNotice('MUNITION LEER');
        }
        return;
      }
      _fireCooldown =
          stats.fireCooldown *
          fireFactor *
          (rapidFireLeft > 0 ? GameConfig.rapidFireFactor : 1);
      if (!endlessAmmo) {
        setAmmo(ammo - 1);
      }
      gameRef.fireFrom(this);
    }
  }

  void setAmmo(int value) {
    ammo = value.clamp(0, stats.ammo);
    if (!isBot) {
      gameRef.ammoNotifier.value = ammo;
    }
  }

  /// Hands out [weapon] with a full set of charges, replacing any other.
  void arm(SpecialWeapon weapon) {
    special = weapon;
    specialCharges = weapon.charges;
    _publishSpecial();
  }

  void _publishSpecial() {
    if (!isBot) {
      final weapon = special;
      gameRef.specialNotifier.value = weapon == null
          ? null
          : (weapon, specialCharges);
    }
  }

  void _handleSpecial(double dt) {
    _specialCooldown -= dt;
    final weapon = special;
    if (weapon == null ||
        _specialCooldown > 0 ||
        !(_special || input.special)) {
      return;
    }
    _specialCooldown = weapon.cooldown;
    gameRef.fireSpecial(this, weapon);
    specialCharges--;
    if (specialCharges <= 0) {
      special = null;
    }
    _publishSpecial();
  }

  void _broadcastState(double dt) {
    _sinceSync += dt;
    _sinceSend += dt;
    if (_sinceSync < syncInterval) {
      return;
    }
    _sinceSync = 0;
    final moved =
        position.distanceTo(_lastSentPosition) > 0.5 ||
        (angle - _lastSentAngle).abs() > 0.01 ||
        (turretAngle - _lastSentTurret).abs() > 0.01;
    if (!moved && _sinceSend < GameConfig.keepaliveInterval) {
      return;
    }
    _sinceSend = 0;
    _lastSentPosition.setFrom(position);
    _lastSentAngle = angle;
    _lastSentTurret = turretAngle;
    gameRef.net.send(
      NetEvent.state,
      ShipStatePayload(
        id: playerId,
        x: position.x,
        y: position.y,
        vx: velocity.x,
        vy: velocity.y,
        rotation: angle,
        hp: hp,
        turret: turretAngle,
      ).toJson(),
    );
  }

  void applyDamage(double amount, {required String? killerId}) {
    if (hp <= 0) {
      return;
    }
    hp -= amount;
    flash();
    if (!isBot) {
      gameRef.hpNotifier.value = hp;
    }
    // Zone ticks are tiny, only real hits get a number and a shake.
    if (amount >= 2) {
      if (isBot) {
        gameRef.showHit(position, amount, mine: killerId == gameRef.myId);
      } else {
        gameRef.onLocalDamage(position, amount);
      }
    }
    if (hp <= 0) {
      if (isBot) {
        gameRef.onBotDeath(this, killerId);
      } else {
        gameRef.onLocalDeath(killerId);
      }
    }
  }

  @override
  void onCollisionStart(
    List<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Bullet &&
        other.ownerId != playerId &&
        !gameRef.sameTeam(playerId, other.ownerId)) {
      other.removeFromParent();
      if (hp <= 0) {
        return;
      }
      AudioService.play('hit');
      if (other.ownerId == gameRef.myId) {
        gameRef.registerHit(min(other.damage, hp));
      }
      applyDamage(other.damage, killerId: other.ownerId);
      gameRef.net.send(
        NetEvent.hit,
        HitPayload(
          id: playerId,
          shooterId: other.ownerId,
          bulletId: other.bulletId,
          hp: hp,
        ).toJson(),
      );
    } else if (other is PowerUp) {
      gameRef.collectPowerUp(other, this);
    } else if (other is Soldier) {
      if (load.abs() > 0.08) {
        gameRef.runOver(other, playerId);
      }
    } else if (other is Asteroid) {
      _treeContacts++;
    } else if (other is Obstacle) {
      final impact = load.abs();
      if (impact > 0.4) {
        applyDamage(3 + 6 * impact, killerId: null);
        AudioService.play('hit', volume: 0.6);
      }
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is Asteroid && _treeContacts > 0) {
      _treeContacts--;
    }
  }

  /// Buildings and barriers are solid: push the tank back out every frame.
  @override
  void onCollision(List<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is! Obstacle) {
      return;
    }
    final rect = other.toRect();
    final radius = GameConfig.shipRadius * 0.85;
    final cx = position.x.clamp(rect.left, rect.right);
    final cy = position.y.clamp(rect.top, rect.bottom);
    final delta = Vector2(position.x - cx, position.y - cy);
    if (delta.length2 > 0) {
      final distance = delta.length;
      if (distance < radius) {
        position.add(delta..scale((radius - distance) / distance));
        _speed *= 0.8;
      }
      return;
    }
    // The centre is inside the rectangle: leave through the nearest side.
    final left = position.x - rect.left;
    final right = rect.right - position.x;
    final top = position.y - rect.top;
    final bottom = rect.bottom - position.y;
    final nearest = [left, right, top, bottom].reduce(min);
    if (nearest == left) {
      position.x = rect.left - radius;
    } else if (nearest == right) {
      position.x = rect.right + radius;
    } else if (nearest == top) {
      position.y = rect.top - radius;
    } else {
      position.y = rect.bottom + radius;
    }
    _speed *= 0.5;
  }
}
