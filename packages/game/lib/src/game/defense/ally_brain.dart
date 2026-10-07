import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';

import '../../game_config.dart';
import '../bot_items.dart';
import '../bot_level.dart';
import '../components/player_ship.dart';
import '../components/power_up.dart';
import '../game_phase.dart';
import '../special_weapon.dart';
import '../space_game.dart';
import '../touch_input.dart';
import 'defense_map.dart';

/// Drives a CPU comrade of a defense round: it rolls from the base up the
/// road to its post on the shoulder, holds it and fires at every enemy that
/// comes into range, also on the way there: tanks, soldiers and, from a
/// Gepard, aircraft and drones. While nothing is in range it fetches crates
/// and gems near its post, keeps them and sets them off when they help.
class AllyBrain extends Component with HasGameRef<SpaceGame> {
  AllyBrain({
    required this.ship,
    required this.controls,
    required this.map,
    required int slot,
  }) : _route = map.allyRoute(slot);

  final PlayerShip ship;
  final TouchInput controls;
  final DefenseMap map;
  final List<Vector2> _route;

  final _random = Random();
  final _items = BotItems(BotLevel.normal);
  int _next = 0;
  double _think = 0;
  double _fireGate = 0;
  double _specialGate = 0;
  double _aimError = 0;
  PositionComponent? _target;

  /// A crate it fetches while the road is quiet.
  PowerUp? _crate;

  /// How far from its post a comrade goes for a crate.
  static const _fetchReach = 300.0;

  @override
  void update(double dt) {
    if (!ship.isMounted) {
      removeFromParent();
      return;
    }
    final phase = gameRef.phase.value;
    if (phase != GamePhase.playing && phase != GamePhase.spectating) {
      controls.reset();
      return;
    }
    _think -= dt;
    if (_think <= 0) {
      _think = 0.25;
      _aimError = (_random.nextDouble() * 2 - 1) * 0.08;
      _target = gameRef.allyTarget(ship, GameConfig.allyRange);
      _crate = _pickCrate();
    }
    _drive();
    _shoot(dt);
    final target = _target;
    controls.lobDistance = target == null || !target.isMounted
        ? null
        : target.position.distanceTo(ship.position);
    _items.think(gameRef, ship, target, dt);
  }

  double _headingTo(Vector2 point) =>
      atan2(point.x - ship.position.x, -(point.y - ship.position.y));

  /// Only once at its post and only while no enemy is in range: a crate
  /// near the post that it can reach without crossing the river.
  PowerUp? _pickCrate() {
    if (_target != null || _next < _route.length - 1) {
      return null;
    }
    final post = _route.last;
    return _items.wanted(
      gameRef,
      ship,
      engaged: false,
      accept: (crate) =>
          crate.position.distanceTo(post) < _fetchReach && _dry(crate.position),
    );
  }

  bool _dry(Vector2 to) {
    final from = ship.position;
    final steps = max(1, (from.distanceTo(to) / 25).ceil());
    for (var i = 1; i <= steps; i++) {
      if (map.inWater(from + (to - from) * (i / steps), margin: 30)) {
        return false;
      }
    }
    return true;
  }

  void _drive() {
    while (_next < _route.length - 1 &&
        ship.position.distanceTo(_route[_next]) < 45) {
      _next++;
    }
    final crate = _crate;
    if (crate != null && !crate.isMounted) {
      // Picked up, by this one or someone else: back to the post.
      _crate = null;
    }
    final goal = _crate?.position ?? _route[_next];
    final distance = ship.position.distanceTo(goal);
    final atPost =
        _crate == null && _next == _route.length - 1 && distance < 22;
    if (atPost) {
      controls
        ..left = false
        ..right = false
        ..thrust = false
        ..brake = ship.velocity.length > 5;
      return;
    }
    final diff = (_headingTo(goal) - ship.angle).toNormalizedAngle();
    final last = _next == _route.length - 1;
    controls
      ..left = diff < -0.06
      ..right = diff > 0.06
      ..thrust = diff.abs() < 0.25 && (!last || distance > 30)
      ..brake =
          (diff.abs() > 0.5 || (last && distance < 60)) &&
          ship.velocity.length > 40;
  }

  void _shoot(double dt) {
    final target = _target;
    if (target == null || !target.isMounted) {
      controls
        ..aim = null
        ..fire = false
        ..special = false;
      _fireGate = 0;
      _specialGate = 0;
      return;
    }
    final flight =
        target.position.distanceTo(ship.position) / ship.stats.bulletSpeed;
    final lead = target.position + gameRef.velocityOfTarget(target) * flight;
    controls.aim = _headingTo(lead) + _aimError;
    final onTarget =
        (controls.aim! - ship.turretAngle).toNormalizedAngle().abs() < 0.12;
    _fireGate = onTarget ? _fireGate + dt : 0;
    controls.fire = _fireGate > 0.25;
    _special(dt, target.position.distanceTo(ship.position), onTarget);
  }

  /// Fires a special weapon from a gem when the target is in its range.
  void _special(double dt, double distance, bool onTarget) {
    final ready = switch (ship.special) {
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
    controls.special = _specialGate > 0.6;
  }
}
