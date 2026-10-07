import 'dart:math';

import 'package:flame/components.dart';

import '../game_config.dart';
import 'bot_level.dart';
import 'components/player_ship.dart';
import 'components/power_up.dart';
import 'space_game.dart';

/// How a CPU tank deals with crates and gems. It keeps them in an inventory
/// of its own like a player and sets them off when they help, not the moment
/// it drives over them. It is also choosy about which ones it goes out of
/// its way for, so the people in the round get most of them.
class BotItems {
  BotItems(this.level);

  final BotLevel level;
  final _random = Random();
  double _cooldown = 2;

  /// Whether the bot cares about a crate, decided once per crate.
  final _interest = <int, bool>{};

  /// How far a bot drives out of its way for a crate it wants.
  double get detour => switch (level) {
    BotLevel.easy => 150,
    BotLevel.normal => 230,
    BotLevel.hard => 300,
  };

  /// Share of crates a bot takes an interest in at all.
  double get _greed => switch (level) {
    BotLevel.easy => 0.25,
    BotLevel.normal => 0.45,
    BotLevel.hard => 0.6,
  };

  /// Seconds between two items, longer on the easy level.
  double get _pause => switch (level) {
    BotLevel.easy => 7,
    BotLevel.normal => 4,
    BotLevel.hard => 2.5,
  };

  /// Whether [ship] is short of what [type] brings, enough to go and get it
  /// whatever else is going on.
  static bool urgent(PlayerShip ship, PowerUpType type) => switch (type) {
    PowerUpType.ammo =>
      !ship.endlessAmmo && ship.ammo <= ship.magazine * GameConfig.ammoLowShare,
    PowerUpType.fuel => ship.usesFuel && ship.fuel < 0.3,
    PowerUpType.repair => ship.hp < ship.stats.maxHp * 0.4,
    _ => false,
  };

  /// Whether [type] would be of any use to [ship] right now.
  static bool useful(PlayerShip ship, PowerUpType type) => switch (type) {
    PowerUpType.ammo => !ship.endlessAmmo && ship.ammo < ship.magazine * 0.7,
    PowerUpType.fuel => ship.usesFuel && ship.fuel < 0.7,
    PowerUpType.repair => ship.hp < ship.stats.maxHp * 0.85,
    _ => true,
  };

  /// The crate the bot should fetch now, if any. [engaged] is set while an
  /// enemy is close: then only what it badly needs is worth the detour.
  PowerUp? wanted(
    SpaceGame game,
    PlayerShip ship, {
    required bool engaged,
    double safeRadius = double.infinity,
  }) {
    final people = game.humanTanks.toList();
    PowerUp? best;
    var bestDistance = double.infinity;
    for (final crate in game.powerUps.values) {
      final type = crate.type;
      if (crate.position.length > safeRadius - 40 ||
          !ship.items.canTake(type) ||
          !useful(ship, type)) {
        continue;
      }
      final distance = crate.position.distanceTo(ship.position);
      final needed = urgent(ship, type);
      if (distance > (needed ? detour * 1.8 : detour) || (engaged && !needed)) {
        continue;
      }
      // Somebody real is closer: leave it to them.
      if (people.any((p) => p.position.distanceTo(crate.position) < distance)) {
        continue;
      }
      final keen = _interest.putIfAbsent(
        crate.slot.id,
        () => _random.nextDouble() < _greed,
      );
      if (!keen && !needed) {
        continue;
      }
      if (distance < bestDistance) {
        bestDistance = distance;
        best = crate;
      }
    }
    return best;
  }

  /// Sets off one item when the moment is right. [target] is the enemy the
  /// bot is fighting, if any.
  void think(
    SpaceGame game,
    PlayerShip ship,
    PositionComponent? target,
    double dt,
  ) {
    _cooldown -= dt;
    if (_cooldown > 0 || ship.items.value.isEmpty) {
      return;
    }
    final distance = target == null || !target.isMounted
        ? double.infinity
        : target.position.distanceTo(ship.position);
    final health = ship.hp / ship.stats.maxHp;
    final slots = ship.items.value;
    for (var i = 0; i < slots.length; i++) {
      final type = slots[i].type;
      final now = switch (type) {
        PowerUpType.repair => health < 0.5,
        PowerUpType.ammo =>
          !ship.endlessAmmo && ship.ammo < ship.magazine * 0.25,
        PowerUpType.fuel => ship.usesFuel && ship.fuel < 0.3,
        PowerUpType.shield => health < 0.65 && distance < 400,
        PowerUpType.smoke => health < 0.35 && distance < 380,
        PowerUpType.rapidFire => distance < 380,
        PowerUpType.mines => distance < 260,
        PowerUpType.artillery => distance < GameConfig.artilleryRange,
        PowerUpType.grenades ||
        PowerUpType.mortar ||
        PowerUpType.drone => ship.special == null && distance < 700,
        PowerUpType.infantry => distance < 420,
        PowerUpType.paratroopers => distance < GameConfig.paraDropRange,
        PowerUpType.hunterDrone ||
        PowerUpType.airstrike => distance < GameConfig.airstrikeReach,
      };
      if (now) {
        _cooldown = _pause * (0.8 + _random.nextDouble() * 0.4);
        game.useBotItem(ship, i);
        return;
      }
    }
    _cooldown = 0.5;
  }
}
