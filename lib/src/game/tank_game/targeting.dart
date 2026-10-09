part of '../tank_game.dart';

/// Questions about the battlefield: who is an enemy, what is nearest, what moves how fast, and what can be seen.
extension TankGameTargeting on TankGame {
  /// Touch aim assist: what the turret of [tank] should go for. In a defense
  /// round the same as a comrade would, otherwise the nearest tank of
  /// another side the player can see.
  PositionComponent? assistTarget(PlayerTank tank) {
    const range = GameConfig.assistRange;
    if (round?.defense ?? false) {
      return allyTarget(tank, range);
    }
    return _nearestOf(tank.position, range, [
      for (final other in _allTanks)
        if (other != tank &&
            other.hp > 0 &&
            !sameTeam(tank.playerId, other.playerId) &&
            canSee(other.position))
          other,
    ]);
  }

  /// What a CPU comrade in [tank] fires at: a Luchs goes for aircraft and
  /// drones first, every comrade for tanks before soldiers.
  PositionComponent? allyTarget(PlayerTank tank, double range) {
    final at = tank.position;
    if (tank.tankType == TankType.luchs) {
      final air = _nearestOf(at, range, [
        for (final plane in aircraft.values)
          if (plane.hp > 0 && !plane.friendly) plane,
        for (final drone in drones.values)
          if (round?.isEnemy(drone.ownerId) ?? false) drone,
      ]);
      if (air != null) {
        return air;
      }
    }
    return nearestEnemy(at, range) ?? _nearestEnemySoldier(at, range);
  }

  T? _nearestOf<T extends PositionComponent>(
    Vector2 from,
    double range,
    Iterable<T> candidates,
  ) {
    T? best;
    var bestDistance = range;
    for (final candidate in candidates) {
      if (!candidate.isMounted) {
        continue;
      }
      final distance = candidate.position.distanceTo(from);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = candidate;
      }
    }
    return best;
  }

  Vector2 velocityOfTarget(PositionComponent target) => switch (target) {
    final TankBase tank => velocityOf(tank),
    final Aircraft plane => plane.velocity,
    final Drone drone => drone.velocity,
    _ => Vector2.zero(),
  };

  // Built without null-aware list elements: such a list literal crashed
  // the Android release build in render(), see _renderWeather.
  Iterable<TankBase> get _allTanks sync* {
    final tank = myTank;
    if (tank != null) yield tank;
    yield* remoteTanks.values;
    yield* botTanks.values;
  }

  TankBase? _nearest(Vector2 from, double range, bool Function(int) team) {
    TankBase? best;
    var bestDistance = range;
    for (final tank in _allTanks) {
      if (!tank.isMounted || tank.hp <= 0 || !team(tank.team)) {
        continue;
      }
      final distance = tank.position.distanceTo(from);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = tank;
      }
    }
    return best;
  }

  /// Closest enemy of a defense round within [range] of [from].
  TankBase? nearestEnemy(Vector2 from, double range) =>
      _nearest(from, range, (team) => team == 2);

  /// Closest player tank within [range] of [from], for the enemies to shoot.
  TankBase? nearestDefender(Vector2 from, double range, {String? of}) {
    final activeRound = round;
    if (activeRound == null || !activeRound.duel) {
      return _nearest(from, range, (team) => team == 1);
    }
    // In a duel whatever fights for one side goes for the other.
    final own = of == null ? 0 : activeRound.teamOf(of);
    return _nearest(
      from,
      range,
      (team) => (team == 1 || team == 2) && team != own,
    );
  }

  /// In a duel: tanks of any side other than [team], the waves included.
  TankBase? nearestHostile(Vector2 from, double range, int team) =>
      _nearest(from, range, (other) => other != 0 && other != team);

  Vector2 velocityOf(TankBase tank) => switch (tank) {
    final PlayerTank local => local.velocity,
    final RemoteTank remote => remote.velocity,
    _ => Vector2.zero(),
  };

  /// The tanks people drive: the local one and those of other players.
  Iterable<TankBase> get humanTanks sync* {
    final activeRound = round;
    final mine = myTank;
    if (mine != null && mine.isMounted && mine.hp > 0) {
      yield mine;
    }
    for (final tank in remoteTanks.values) {
      if (tank.hp > 0 && !(activeRound?.isBot(tank.playerId) ?? false)) {
        yield tank;
      }
    }
  }

  /// Tanks [id] may shoot at: everybody alive outside its own team.
  Iterable<TankBase> enemiesOf(String id) sync* {
    final candidates = <TankBase?>[
      myTank,
      ...remoteTanks.values,
      ...botTanks.values,
    ];
    for (final tank in candidates) {
      if (tank != null &&
          tank.isMounted &&
          tank.hp > 0 &&
          tank.playerId != id &&
          !sameTeam(id, tank.playerId)) {
        yield tank;
      }
    }
  }

  /// Whether the local player can make out [point] through night, fog or
  /// sand. Without a tank of one's own everything is visible.
  bool canSee(Vector2 point) {
    final vision = conditions?.vision;
    final tank = myTank;
    if (vision == null || tank == null || phase.value != GamePhase.playing) {
      return true;
    }
    return tank.position.distanceTo(point) <= vision;
  }

  /// Whether a soldier of [owner] is on the side of [id]: its own soldiers,
  /// teammates and their soldiers. Bystanders have no side.
  bool allied(String? owner, String id) =>
      owner != null && (owner == id || sameTeam(owner, id));

  /// Whether [point] lies in a cloud of smoke.
  bool inSmoke(Vector2 point) => smokes.any((cloud) => cloud.covers(point));
}
