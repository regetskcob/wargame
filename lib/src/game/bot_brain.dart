import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';

import 'game_config.dart';
import 'bot_items.dart';
import 'bot_level.dart';
import 'components/artillery_strike.dart';
import 'components/obstacle.dart';
import 'components/player_tank.dart';
import 'components/remote_tank.dart';
import 'components/tank_base.dart';
import 'game_phase.dart';
import 'tank_game.dart';
import 'special_weapon.dart';
import 'touch_input.dart';

/// Drives a computer controlled tank by pressing the same virtual buttons a
/// player has: it hunts the nearest enemy, keeps its distance, shoots with a
/// bit of lead and error, stays inside the closing zone and backs out when it
/// gets stuck.
class BotBrain extends Component with HasGameRef<TankGame> {
  BotBrain({
    required this.tank,
    required this.controls,
    this.level = BotLevel.normal,
    this.objective,
  }) : items = BotItems(level);

  final PlayerTank tank;
  final TouchInput controls;
  final BotLevel level;
  final BotItems items;

  /// Where the round wants this tank to go when no enemy is close, null to
  /// just hunt: the flags of a capture the flag round.
  final Vector2? Function(PlayerTank tank)? objective;

  final _random = Random();
  double _think = 0;
  double _aimError = 0;
  double _errorTimer = 0;
  double _fireGate = 0;
  double _specialGate = 0;
  double _stuckTimer = 0;
  double _reverseTimer = 0;
  double _reverseTurn = 1;
  double _strafeSide = 1;
  double _strafeTimer = 0;
  final _lastPosition = Vector2.zero();
  double _desiredHeading = 0;
  bool _wantThrust = false;
  bool _wantBrake = false;
  bool _hasLineOfSight = false;
  TankBase? _target;

  @override
  void update(double dt) {
    if (!tank.isMounted) {
      removeFromParent();
      return;
    }
    if (gameRef.phase.value != GamePhase.playing &&
        gameRef.phase.value != GamePhase.spectating) {
      controls.reset();
      return;
    }
    _errorTimer -= dt;
    if (_errorTimer <= 0) {
      _errorTimer = 0.6;
      _aimError = (_random.nextDouble() * 2 - 1) * level.aimError;
    }
    _strafeTimer -= dt;
    if (_strafeTimer <= 0) {
      _strafeTimer = 1.5 + _random.nextDouble() * 2;
      _strafeSide = _random.nextBool() ? 1 : -1;
    }
    _think -= dt;
    if (_think <= 0) {
      _think = level.think;
      _decide();
    }
    _steer(dt);
    _gunnery(dt);
    items.think(gameRef, tank, _target, dt);
  }

  /// Nearest tank that is not on this bot's team.
  TankBase? _pickTarget() {
    TankBase? best;
    var bestDistance = double.infinity;
    void consider(TankBase? candidate) {
      if (candidate == null ||
          candidate == tank ||
          !candidate.isMounted ||
          gameRef.sameTeam(tank.playerId, candidate.playerId)) {
        return;
      }
      final distance = candidate.position.distanceTo(tank.position);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = candidate;
      }
    }

    consider(gameRef.myTank);
    gameRef.remoteTanks.values.forEach(consider);
    gameRef.botTanks.values.forEach(consider);
    return best;
  }

  Vector2 _velocityOf(TankBase target) {
    if (target is PlayerTank) {
      return target.velocity;
    }
    if (target is RemoteTank) {
      return target.velocity;
    }
    return Vector2.zero();
  }

  double _headingTo(Vector2 point) =>
      atan2(point.x - tank.position.x, -(point.y - tank.position.y));

  Iterable<Obstacle> get _obstacles =>
      gameRef.world.descendants().whereType<Obstacle>();

  bool _blocked(Vector2 point, {double margin = 0}) {
    for (final obstacle in _obstacles) {
      if (obstacle.toRect().inflate(margin).contains(point.toOffset())) {
        return true;
      }
    }
    return false;
  }

  void _decide() {
    final round = gameRef.round;
    final target = _pickTarget();
    _target = target;
    final safeRadius = round == null
        ? GameConfig.worldRadius
        : round.safeRadiusAt(DateTime.now().millisecondsSinceEpoch);
    _wantThrust = false;
    _wantBrake = false;

    final barrage = level.evasive ? _barrageOverhead() : null;
    final goal = objective?.call(tank);
    final targetDistance = target?.position.distanceTo(tank.position);
    // A carrier runs for home whatever happens, the others leave the
    // objective for an enemy that comes close.
    final onTheWay =
        goal != null &&
        (tank.carriesFlag || targetDistance == null || targetDistance > 260);
    final pickup = items.wanted(
      gameRef,
      tank,
      engaged:
          target != null && target.position.distanceTo(tank.position) < 320,
      safeRadius: safeRadius,
    );
    if (tank.position.length > safeRadius - 70) {
      // Back into the safe circle first.
      _desiredHeading = _headingTo(Vector2.zero());
      _wantThrust = true;
    } else if (barrage != null) {
      // Get out from under the shells.
      _desiredHeading = _headingTo(tank.position * 2 - barrage.position);
      _wantThrust = true;
    } else if (onTheWay) {
      _desiredHeading = _headingTo(goal);
      _wantThrust = goal.distanceTo(tank.position) > 20;
      if (target != null) {
        _hasLineOfSight = _clearShot(target.position);
      }
    } else if (pickup != null) {
      _desiredHeading = _headingTo(pickup.position);
      _wantThrust = true;
      if (target != null) {
        _hasLineOfSight = _clearShot(target.position);
      }
    } else if (target == null) {
      _desiredHeading = _headingTo(Vector2.zero());
      _wantThrust = tank.position.length > 160;
    } else {
      final distance = target.position.distanceTo(tank.position);
      final toTarget = _headingTo(target.position);
      if (distance > 340) {
        _desiredHeading = toTarget;
        _wantThrust = true;
      } else if (distance < 170) {
        _desiredHeading = toTarget;
        _wantBrake = true;
      } else {
        // Circle the target instead of standing still.
        _desiredHeading = toTarget + _strafeSide * pi / 2;
        _wantThrust = true;
      }
      _hasLineOfSight = _clearShot(target.position);
    }

    // Keep out of walls: turn away when something solid is right ahead.
    final ahead = tank.position + tank.direction * 70;
    if (_wantThrust && _blocked(ahead, margin: 12)) {
      _desiredHeading = tank.angle + 1.4 * _strafeSide;
    }

    // Stuck: nearly no progress although the tank is driving.
    if (_wantThrust || _wantBrake) {
      if (tank.position.distanceTo(_lastPosition) < 5) {
        _stuckTimer += 0.15;
      } else {
        _stuckTimer = 0;
      }
    } else {
      _stuckTimer = 0;
    }
    _lastPosition.setFrom(tank.position);
    if (_stuckTimer > 0.9) {
      _stuckTimer = 0;
      _reverseTimer = 0.8;
      _reverseTurn = _random.nextBool() ? 1 : -1;
    }
  }

  /// A barrage of an enemy that is about to land on this bot.
  ArtilleryStrike? _barrageOverhead() {
    for (final strike in gameRef.world.children.whereType<ArtilleryStrike>()) {
      if (strike.ownerId != tank.playerId &&
          !gameRef.sameTeam(strike.ownerId, tank.playerId) &&
          strike.position.distanceTo(tank.position) <
              GameConfig.artilleryRadius + GameConfig.tankRadius * 2) {
        return strike;
      }
    }
    return null;
  }

  bool _clearShot(Vector2 to) {
    final from = tank.position;
    final steps = (from.distanceTo(to) / 24).ceil();
    for (var i = 1; i < steps; i++) {
      final point = from + (to - from) * (i / steps);
      if (_blocked(point)) {
        return false;
      }
    }
    return true;
  }

  void _steer(double dt) {
    controls
      ..left = false
      ..right = false
      ..thrust = false
      ..brake = false;
    if (_reverseTimer > 0) {
      _reverseTimer -= dt;
      controls.brake = true;
      controls.left = _reverseTurn < 0;
      controls.right = _reverseTurn > 0;
      return;
    }
    final diff = (_desiredHeading - tank.angle).toNormalizedAngle();
    controls.left = diff < -0.1;
    controls.right = diff > 0.1;
    final facing = diff.abs() < 1.3;
    controls.thrust = _wantThrust && facing;
    controls.brake = _wantBrake && facing;
  }

  void _gunnery(double dt) {
    final target = _target;
    if (target == null || !target.isMounted) {
      controls
        ..fire = false
        ..special = false;
      _fireGate = 0;
      _specialGate = 0;
      return;
    }
    final distance = target.position.distanceTo(tank.position);
    final stats = tank.stats;
    final flight = distance / stats.bulletSpeed;
    final aimPoint =
        target.position + _velocityOf(target) * (flight * level.lead);
    final error = _aimError * (0.5 + distance / 500);
    controls.aim = _headingTo(aimPoint) + error;

    final range = stats.bulletSpeed * GameConfig.bulletTtl * 0.9;
    final onTarget =
        (controls.aim! - tank.turretAngle).toNormalizedAngle().abs() < 0.12;
    if (distance < range && _hasLineOfSight && onTarget) {
      _fireGate += dt;
    } else {
      _fireGate = 0;
    }
    // A short reaction time before the first shot at a fresh target.
    controls.fire = _fireGate > level.reaction && tank.ammo > 0;
    _special(dt, aimPoint, onTarget);
  }

  /// Grenades go at targets in lobbing range, wall or not. The drone goes up
  /// as soon as there is anybody to hunt.
  void _special(double dt, Vector2 aimPoint, bool onTarget) {
    final distance = aimPoint.distanceTo(tank.position);
    final ready = switch (tank.special) {
      SpecialWeapon.grenades =>
        onTarget &&
            distance > GameConfig.grenadeMinRange + 40 &&
            distance < GameConfig.grenadeRange,
      SpecialWeapon.mortar =>
        distance > GameConfig.mortarMinRange + 40 &&
            distance < GameConfig.mortarRange,
      SpecialWeapon.drone => distance < 700,
      SpecialWeapon.shell || null => false,
    };
    _specialGate = ready ? _specialGate + dt : 0;
    controls
      ..lobDistance = distance
      ..special = _specialGate > 0.8;
  }
}
