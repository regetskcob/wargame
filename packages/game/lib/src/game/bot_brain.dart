import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';

import '../game_config.dart';
import 'bot_level.dart';
import 'components/artillery_strike.dart';
import 'components/obstacle.dart';
import 'components/player_ship.dart';
import 'components/power_up.dart';
import 'components/remote_ship.dart';
import 'components/ship_base.dart';
import 'components/storm_zone.dart';
import 'game_phase.dart';
import 'space_game.dart';
import 'special_weapon.dart';
import 'touch_input.dart';

/// Drives a computer controlled tank by pressing the same virtual buttons a
/// player has: it hunts the nearest enemy, keeps its distance, shoots with a
/// bit of lead and error, stays inside the closing zone and backs out when it
/// gets stuck.
class BotBrain extends Component with HasGameRef<SpaceGame> {
  BotBrain({
    required this.ship,
    required this.controls,
    this.level = BotLevel.normal,
  });

  final PlayerShip ship;
  final TouchInput controls;
  final BotLevel level;

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
  ShipBase? _target;

  @override
  void update(double dt) {
    if (!ship.isMounted) {
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
  }

  /// Nearest tank that is not on this bot's team.
  ShipBase? _pickTarget() {
    ShipBase? best;
    var bestDistance = double.infinity;
    void consider(ShipBase? candidate) {
      if (candidate == null ||
          candidate == ship ||
          !candidate.isMounted ||
          gameRef.sameTeam(ship.playerId, candidate.playerId)) {
        return;
      }
      final distance = candidate.position.distanceTo(ship.position);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = candidate;
      }
    }

    consider(gameRef.myShip);
    gameRef.remoteShips.values.forEach(consider);
    gameRef.botShips.values.forEach(consider);
    return best;
  }

  Vector2 _velocityOf(ShipBase target) {
    if (target is PlayerShip) {
      return target.velocity;
    }
    if (target is RemoteShip) {
      return target.velocity;
    }
    return Vector2.zero();
  }

  double _headingTo(Vector2 point) =>
      atan2(point.x - ship.position.x, -(point.y - ship.position.y));

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
        : StormZone.radiusAt(
            round.startedAt,
            DateTime.now().millisecondsSinceEpoch,
          );
    _wantThrust = false;
    _wantBrake = false;

    final barrage = level.evasive ? _barrageOverhead() : null;
    final pickup = _wantedPickup(safeRadius);
    if (ship.position.length > safeRadius - 70) {
      // Back into the safe circle first.
      _desiredHeading = _headingTo(Vector2.zero());
      _wantThrust = true;
    } else if (barrage != null) {
      // Get out from under the shells.
      _desiredHeading = _headingTo(ship.position * 2 - barrage.position);
      _wantThrust = true;
    } else if (pickup != null) {
      _desiredHeading = _headingTo(pickup.position);
      _wantThrust = true;
      if (target != null) {
        _hasLineOfSight = _clearShot(target.position);
      }
    } else if (target == null) {
      _desiredHeading = _headingTo(Vector2.zero());
      _wantThrust = ship.position.length > 160;
    } else {
      final distance = target.position.distanceTo(ship.position);
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
    final ahead = ship.position + ship.direction * 70;
    if (_wantThrust && _blocked(ahead, margin: 12)) {
      _desiredHeading = ship.angle + 1.4 * _strafeSide;
    }

    // Stuck: nearly no progress although the tank is driving.
    if (_wantThrust || _wantBrake) {
      if (ship.position.distanceTo(_lastPosition) < 5) {
        _stuckTimer += 0.15;
      } else {
        _stuckTimer = 0;
      }
    } else {
      _stuckTimer = 0;
    }
    _lastPosition.setFrom(ship.position);
    if (_stuckTimer > 0.9) {
      _stuckTimer = 0;
      _reverseTimer = 0.8;
      _reverseTurn = _random.nextBool() ? 1 : -1;
    }
  }

  /// A barrage of an enemy that is about to land on this bot.
  ArtilleryStrike? _barrageOverhead() {
    for (final strike in gameRef.world.children.whereType<ArtilleryStrike>()) {
      if (strike.ownerId != ship.playerId &&
          !gameRef.sameTeam(strike.ownerId, ship.playerId) &&
          strike.position.distanceTo(ship.position) <
              GameConfig.artilleryRadius + GameConfig.shipRadius * 2) {
        return strike;
      }
    }
    return null;
  }

  /// A gem worth a detour: any ammo gem once the magazine runs low, and a
  /// nearby special weapon gem while the bot has none.
  PowerUp? _wantedPickup(double safeRadius) {
    final lowAmmo = ship.ammo <= ship.stats.ammo * GameConfig.ammoLowShare;
    PowerUp? best;
    var bestDistance = double.infinity;
    for (final crate in gameRef.powerUps.values) {
      if (crate.position.length > safeRadius - 40) {
        continue;
      }
      final distance = crate.position.distanceTo(ship.position);
      final wanted = switch (crate.type) {
        PowerUpType.ammo => lowAmmo,
        PowerUpType.grenades ||
        PowerUpType.drone => ship.special == null && distance < 350,
        _ => false,
      };
      if (wanted && distance < bestDistance) {
        bestDistance = distance;
        best = crate;
      }
    }
    return best;
  }

  bool _clearShot(Vector2 to) {
    final from = ship.position;
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
    final diff = (_desiredHeading - ship.angle).toNormalizedAngle();
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
    final distance = target.position.distanceTo(ship.position);
    final stats = ship.stats;
    final flight = distance / stats.bulletSpeed;
    final aimPoint =
        target.position + _velocityOf(target) * (flight * level.lead);
    final error = _aimError * (0.5 + distance / 500);
    controls.aim = _headingTo(aimPoint) + error;

    final range = stats.bulletSpeed * GameConfig.bulletTtl * 0.9;
    final onTarget =
        (controls.aim! - ship.turretAngle).toNormalizedAngle().abs() < 0.12;
    if (distance < range && _hasLineOfSight && onTarget) {
      _fireGate += dt;
    } else {
      _fireGate = 0;
    }
    // A short reaction time before the first shot at a fresh target.
    controls.fire = _fireGate > level.reaction && ship.ammo > 0;
    _special(dt, aimPoint, onTarget);
  }

  /// Grenades go at targets in lobbing range, wall or not. The drone goes up
  /// as soon as there is anybody to hunt.
  void _special(double dt, Vector2 aimPoint, bool onTarget) {
    final distance = aimPoint.distanceTo(ship.position);
    final ready = switch (ship.special) {
      SpecialWeapon.grenades =>
        onTarget &&
            distance > GameConfig.grenadeMinRange + 40 &&
            distance < GameConfig.grenadeRange,
      SpecialWeapon.drone => distance < 700,
      null => false,
    };
    _specialGate = ready ? _specialGate + dt : 0;
    controls
      ..lobDistance = distance
      ..special = _specialGate > 0.8;
  }
}
