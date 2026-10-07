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
import '../tank_damage.dart';
import '../touch_input.dart';
import '../space_game.dart';
import 'asteroid.dart';
import 'mine.dart';
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
  double shieldLeft = 0;

  /// Upgrades bought in a defense round: share of the damage the armour
  /// lets through, and factors on the gun, the engine and the magazine.
  double armorFactor = 1;
  double gunFactor = 1;
  double engineFactor = 1;
  double magazineFactor = 1;

  /// Rounds a full magazine holds.
  int get magazine => (stats.ammo * magazineFactor).round();

  /// Rounds left in the magazine. Gems put more back.
  late int ammo = magazine;

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
  final _trees = <Asteroid>{};

  /// Drift a battered running gear puts on the heading, and where it heads.
  double _wobble = 0;
  double _wobbleTarget = 0;
  double _wobbleTimer = 0;

  /// Seconds the engine still sputters after a misfire.
  double _stall = 0;

  /// Worst stage the driver has been warned about, to warn only once.
  DamageStage _announced = DamageStage.intact;
  static final _random = Random();

  /// Keys 1 to 6 set off the items in the inventory.
  static final _itemKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
  ];

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
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.keyB) {
        gameRef.buildTower();
      } else if (key == LogicalKeyboardKey.keyV) {
        gameRef.cycleTowerKind();
      } else {
        final slot = _itemKeys.indexOf(key);
        if (slot >= 0) {
          gameRef.useItem(slot);
        }
      }
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
    _tickShield(dt);
    _integrate(dt);
    _aim(dt);
    _applyZoneDamage(dt);
    _handleFire(dt);
    _handleSpecial(dt);
    _broadcastState(dt);
  }

  void _tickShield(double dt) {
    if (shieldLeft <= 0) {
      return;
    }
    shieldLeft = max(0, shieldLeft - dt);
    shielded = shieldLeft > 0;
    if (!isBot) {
      gameRef.shieldSeconds.value = shieldLeft.ceil();
    }
  }

  /// Tracks drive along the hull, so the tank never slides sideways: the
  /// velocity vector is always derived from the heading and [_speed].
  void _integrate(double dt) {
    var thrusting = _thrust || input.thrust;
    var braking = _brake || input.brake;
    var turn =
        (((_right || input.right) ? 1 : 0) - ((_left || input.left) ? 1 : 0))
            .toDouble();
    // Steering follows the direction of travel: in reverse, left swings the
    // rear to the left like a car would. Bots steer by heading, so not them.
    final reversing = _speed < 0 || (_speed == 0 && braking && !thrusting);
    if (reversing && !isBot) {
      turn = -turn;
    }
    // The touch drive stick points where to go: turn that way, and roll once
    // the hull roughly faces it.
    final drive = isBot ? null : input.drive;
    if (drive != null) {
      final (dx, dy) = drive;
      final diff = (atan2(dx, -dy) - angle).toNormalizedAngle();
      turn = (diff * 2.5).clamp(-1.0, 1.0);
      thrusting = sqrt(dx * dx + dy * dy) > 0.3 && diff.abs() < 1.0;
      braking = false;
    }
    // Woods drag the tank down to about half its speed, soft ground to 60 %.
    final soft = gameRef.mudField?.softAt(position) ?? false;
    // Hits cost top speed, pulling power and steering.
    final damage = this.damage;
    final maxSpeed =
        GameConfig.shipMaxSpeed *
        stats.speed *
        speedFactor *
        engineFactor *
        damage.speedFactor *
        min(_trees.any((t) => !t.felled) ? 0.55 : 1.0, soft ? 0.6 : 1.0);
    final acceleration =
        GameConfig.shipAcceleration *
        stats.acceleration *
        damage.accelerationFactor;
    // Tracks turn slower at full speed, and almost on the spot when standing.
    final turnScale = 1 - 0.35 * (_speed.abs() / maxSpeed);
    angle +=
        turn *
        GameConfig.shipRotationSpeed *
        stats.turnRate *
        damage.turnFactor *
        turnScale *
        dt;
    _rattle(damage, maxSpeed, dt);

    // A misfiring engine drops the throttle for a moment.
    _stall = max(0, _stall - dt);
    if (thrusting &&
        _stall <= 0 &&
        _random.nextDouble() < damage.stallRate * dt) {
      _stall = 0.25 + _random.nextDouble() * 0.35;
      backfire();
      if (!isBot) {
        gameRef.shake(2);
        AudioService.play('tick', volume: 0.5);
      }
    }
    if (_stall > 0) {
      final decel = GameConfig.shipRollingResistance * 0.3 * dt;
      _speed = _speed.abs() <= decel ? 0 : _speed - decel * _speed.sign;
    } else if (thrusting) {
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
    _speed = _speed.clamp(
      -GameConfig.shipReverseSpeed * damage.speedFactor,
      maxSpeed,
    );

    velocity
      ..setFrom(direction)
      ..scale(_speed);
    final before = position.clone();
    position.add(velocity * dt);
    final map = gameRef.defenseMap;
    if (map != null) {
      _keepOutOfWater(map, before);
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

  /// The river can only be crossed on a bridge. A tank that drives into the
  /// bank slides along it instead.
  void _keepOutOfWater(DefenseMap map, Vector2 before) {
    const margin = GameConfig.shipRadius * 0.6;
    if (!map.inWater(position, margin: margin)) {
      return;
    }
    final slideX = Vector2(position.x, before.y);
    final slideY = Vector2(before.x, position.y);
    if (!map.inWater(slideX, margin: margin)) {
      position.setFrom(slideX);
    } else if (!map.inWater(slideY, margin: margin)) {
      position.setFrom(slideY);
    } else {
      position.setFrom(before);
    }
    _speed *= 0.6;
  }

  /// A damaged running gear makes the ride rough: the heading drifts, broken
  /// track links knock the tank about and the driver feels every one of them.
  void _rattle(TankDamage damage, double maxSpeed, double dt) {
    final rough = damage.bumpiness;
    final pace = maxSpeed <= 0 ? 0.0 : (_speed.abs() / maxSpeed).clamp(0, 1);
    if (rough <= 0 || pace < 0.05) {
      _wobble *= max(0, 1 - dt * 4);
      return;
    }
    _wobbleTimer -= dt;
    if (_wobbleTimer <= 0) {
      _wobbleTimer = 0.15 + _random.nextDouble() * 0.35;
      _wobbleTarget = (_random.nextDouble() * 2 - 1) * 0.8;
    }
    _wobble += (_wobbleTarget - _wobble) * min(1.0, dt * 6);
    angle += _wobble * rough * pace * dt;
    // Every so often a hard knock robs the tank of some of its speed.
    if (_random.nextDouble() < rough * pace * 1.6 * dt) {
      _speed *= 0.82;
      angle += (_random.nextDouble() * 2 - 1) * 0.06 * rough;
      bump(0.25 + 0.35 * rough);
      if (!isBot) {
        gameRef.shake(1.5 + 2.5 * rough);
      }
    } else if (!isBot) {
      // A steady judder that grows with damage and speed.
      gameRef.shake(28 * dt * 0.9 * rough * pace);
    }
  }

  /// The turret turns on its own: with the mouse, the aim stick or Q and E.
  /// Until one of them is used it simply follows the hull.
  void _aim(double dt) {
    // A hit turret ring grinds and turns slower.
    final drive = damage.turretFactor;
    final turretSpeed = 10.0 * drive;
    final keys = (_turretRight ? 1 : 0) - (_turretLeft ? 1 : 0);
    double? target;
    final stick = input.aim;
    var assisted = false;
    if (!isBot && input.assist && !input.aimHeld) {
      final prey = gameRef.assistTarget(this);
      if (prey != null) {
        final flight = prey.position.distanceTo(position) / stats.bulletSpeed;
        final lead = prey.position + gameRef.velocityOfTarget(prey) * flight;
        target = atan2(lead.x - position.x, -(lead.y - position.y));
        assisted = true;
      }
    }
    if (!assisted && stick != null) {
      target = stick;
    } else if (!assisted && !isBot) {
      final point = gameRef.pointerWorld();
      // Inside the hull the angle to the cursor flips wildly: hold still.
      if (point != null && point.distanceTo(position) > 30) {
        target = atan2(point.x - position.x, -(point.y - position.y));
      }
    }
    if (keys != 0) {
      _aimed = true;
      turretAngle += keys * 3 * drive * dt;
    } else if (target != null) {
      _aimed = true;
      final diff = (target - turretAngle).toNormalizedAngle();
      turretAngle += diff.abs() < 0.02
          ? diff
          : diff.clamp(-turretSpeed * dt, turretSpeed * dt);
    } else if (!_aimed) {
      turretAngle = angle;
    }
    if (!isBot) {
      input.assistFire =
          assisted &&
          target != null &&
          (target - turretAngle).toNormalizedAngle().abs() < 0.1;
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
    if ((_fire || input.fire || input.aimFire || input.assistFire) &&
        _fireCooldown <= 0) {
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
    ammo = value.clamp(0, magazine);
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
        shielded ||
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
        shielded: shielded,
      ).toJson(),
    );
  }

  void applyDamage(double amount, {required String? killerId}) {
    if (hp <= 0) {
      return;
    }
    // The shield holds off shells, mines and barrages, not the zone.
    if (shielded && killerId != null) {
      amount *= GameConfig.shieldFactor;
    }
    if (killerId != null) {
      amount *= armorFactor;
      if (gameRef.inTrench(position)) {
        amount *= GameConfig.trenchCover;
      }
    }
    hp -= amount;
    takeHitEffects(amount);
    // A real hit knocks the hull and the turret off line and brakes the tank.
    if (amount >= 5 && hp > 0) {
      final kick = min(0.16, amount / 260);
      angle += (_random.nextBool() ? 1 : -1) * kick * _random.nextDouble();
      turretAngle += (_random.nextBool() ? 1 : -1) * kick * 1.5;
      _speed *= max(0.55, 1 - amount / 80);
    }
    if (!isBot) {
      gameRef.hpNotifier.value = hp;
      gameRef.roundStats.damageTaken += amount;
      _announceDamage();
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

  /// Tells the driver once per stage what broke. A repair crate that patches
  /// the tank up lets the warnings come again.
  void _announceDamage() {
    final stage = damage.stage;
    if (stage.index < _announced.index) {
      _announced = stage;
    }
    if (hp <= 0 || stage.index <= _announced.index) {
      return;
    }
    _announced = stage;
    final notice = stage.notice;
    if (notice != null) {
      gameRef.showNotice(notice);
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
    } else if (other is Mine) {
      if (other.armed &&
          other.ownerId != playerId &&
          !gameRef.sameTeam(playerId, other.ownerId)) {
        gameRef.triggerMine(other, this);
      }
    } else if (other is PowerUp) {
      gameRef.collectPowerUp(other, this);
    } else if (other is Soldier) {
      if (load.abs() > 0.08 &&
          !other.airborne &&
          !gameRef.allied(other.ownerId, playerId)) {
        gameRef.runOver(other, playerId, crushed: true);
      }
    } else if (other is Asteroid) {
      _trees.add(other);
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
    if (other is Asteroid) {
      _trees.remove(other);
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
