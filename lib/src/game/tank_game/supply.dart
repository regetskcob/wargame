part of '../tank_game.dart';

/// Fuel stations and ammunition depots: placing them, filling up the tanks
/// this client runs, and shells and blasts that bring them down.
extension TankGameSupply on TankGame {
  /// Puts the depots of a free for all or capture the flag round on the
  /// map. The easy level has no fuel and endless shells, so it needs none.
  void _setUpSupply(RoundState activeRound) {
    final cover = _coverField;
    if (cover == null || activeRound.botLevel == BotLevel.easy) {
      return;
    }
    supplyField = SupplyField(
      seed: activeRound.seed,
      flag: activeRound.flag,
      cover: cover,
    );
    world.add(supplyField!);
  }

  void _clearSupply() {
    supplyField?.removeFromParent();
    supplyField = null;
    _depotHinted = false;
  }

  Iterable<SupplyDepot> get depots => supplyField?.depots ?? const [];

  /// Whether the shells of [ownerId] wear [depot] down. A team's own depots
  /// are behind its lines, its shells fly over them.
  bool hurtsDepot(String ownerId, SupplyDepot depot) {
    if (depot.team == 0) {
      return true;
    }
    final activeRound = round;
    return activeRound != null && activeRound.teamOf(ownerId) != depot.team;
  }

  /// The depot of [kind] nearest to [tank] that serves its team, if any.
  SupplyDepot? nearestDepot(PlayerTank tank, DepotKind kind) {
    final team = round?.teamOf(tank.playerId) ?? 0;
    SupplyDepot? best;
    var bestDistance = double.infinity;
    for (final depot in depots) {
      if (depot.kind != kind || !depot.serves(team)) {
        continue;
      }
      final distance = depot.position.distanceTo(tank.position);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = depot;
      }
    }
    return best;
  }

  /// Fills up the local tank and the CPU tanks of this host while they
  /// stand still on a depot that serves them.
  void _updateSupply(double dt) {
    final field = supplyField;
    if (field == null) {
      return;
    }
    for (final depot in field.depots) {
      depot.filling = false;
    }
    if (phase.value != GamePhase.playing &&
        phase.value != GamePhase.spectating) {
      return;
    }
    final mine = myTank;
    if (mine != null && phase.value == GamePhase.playing) {
      final depot = _fillUp(mine, dt);
      _hintDepot(mine, depot);
    }
    for (final bot in botTanks.values) {
      _fillUp(bot, dt);
    }
  }

  /// Fills [tank] from the depot it stands on and returns that depot, also
  /// when the tank still rolls and gets nothing yet.
  SupplyDepot? _fillUp(PlayerTank tank, double dt) {
    if (tank.hp <= 0 || !tank.isMounted) {
      return null;
    }
    final team = round?.teamOf(tank.playerId) ?? 0;
    final depot = depots
        .where((d) => d.serves(team) && d.covers(tank.position))
        .firstOrNull;
    if (depot == null) {
      tank.ammoCarry = 0;
      return null;
    }
    if (tank.velocity.length > GameConfig.depotStandSpeed) {
      return depot;
    }
    switch (depot.kind) {
      case DepotKind.fuel:
        if (tank.usesFuel && tank.fuel < 1) {
          tank.setFuel(tank.fuel + dt / GameConfig.depotFillSeconds);
          depot.filling = tank == myTank;
        }
      case DepotKind.ammo:
        if (!tank.endlessAmmo && tank.ammo < tank.magazine) {
          tank.ammoCarry += dt * tank.magazine / GameConfig.depotFillSeconds;
          final rounds = tank.ammoCarry.floor();
          if (rounds > 0) {
            tank
              ..ammoCarry -= rounds
              ..setAmmo(tank.ammo + rounds);
          }
          depot.filling = tank == myTank;
        }
    }
    return depot;
  }

  /// Tells the player once per visit to stop when they roll onto a depot
  /// they could use.
  void _hintDepot(PlayerTank tank, SupplyDepot? depot) {
    if (depot == null) {
      _depotHinted = false;
      return;
    }
    final needs = switch (depot.kind) {
      DepotKind.fuel => tank.usesFuel && tank.fuel < 0.95,
      DepotKind.ammo => !tank.endlessAmmo && tank.ammo < tank.magazine,
    };
    if (_depotHinted || !needs || depot.filling) {
      return;
    }
    _depotHinted = true;
    showNotice(
      depot.kind == DepotKind.fuel
          ? tr('ANHALTEN ZUM TANKEN', 'STOP TO REFUEL')
          : tr('ANHALTEN ZUM NACHLADEN', 'STOP TO RELOAD'),
    );
  }

  /// A shell of [ownerId] hit [depot]. Only the shooter's client applies it
  /// and tells the others.
  void damageDepot(SupplyDepot depot, double damage, String ownerId) {
    if (depot.destroyed || !hurtsDepot(ownerId, depot)) {
      return;
    }
    final hp = max(0.0, depot.hp - damage);
    _setDepotHp(depot, hp, ownerId);
    net.send(
      NetEvent.obstacle,
      ObstaclePayload(
        id: ownerId,
        index: depot.index,
        hp: hp,
        depot: true,
      ).toJson(),
    );
  }

  /// Wears down every depot within [radius] of a blast at [at].
  void _blastDepots(String ownerId, Vector2 at, double radius, double damage) {
    for (final depot in depots) {
      if (depot.position.distanceTo(at) < radius + GameConfig.depotCoreRadius) {
        damageDepot(depot, damage, ownerId);
      }
    }
  }

  void _onDepot(ObstaclePayload payload) {
    final depot = supplyField?.depotAt(payload.index);
    if (depot == null) {
      return;
    }
    // Rebuilt here a moment later than there, or a late hit on a depot
    // that already went up: only ever take the news that moves it along.
    if (depot.destroyed ? payload.hp > 0 : payload.hp < depot.hp) {
      _setDepotHp(depot, payload.hp, payload.id);
    }
  }

  void _setDepotHp(SupplyDepot depot, double hp, String ownerId) {
    final at = depot.position.clone();
    if (!depot.setHp(hp)) {
      AudioService.play('hit', volume: 0.7, distance: _distanceToView(at));
      return;
    }
    // It went up: fire, a crater, and the tanks this client runs that stood
    // too close take the blast. The tank that fired gets the credit.
    AudioService.play('explosion', distance: _distanceToView(at));
    addCrater(at, 26);
    shakeAt(at, 9);
    world.addAll([
      for (var i = 0; i < 4; i++)
        Explosion(
          position: at + Vector2(cos(i * 1.9), sin(i * 1.9)) * 18,
          color: depot.kind.color,
        ),
      puff(
        position: at,
        color: const Color(0xFF2E2A24),
        count: 14,
        lifespan: 2.2,
        speed: (15, 60),
        size: (8, 18),
        opacity: 0.7,
      ),
    ]);
    showNotice(
      tr('${depot.kind.label} ZERSTÖRT', '${depot.kind.label} DESTROYED'),
    );
    if (replaying.value) {
      return;
    }
    final tanks = <PlayerTank>[...botTanks.values];
    final mine = myTank;
    if (mine != null) tanks.insert(0, mine);
    for (final tank in tanks) {
      if (tank.playerId == ownerId || sameTeam(tank.playerId, ownerId)) {
        continue;
      }
      final distance = tank.position.distanceTo(at);
      if (distance > GameConfig.depotBlastRadius + GameConfig.tankRadius) {
        continue;
      }
      final falloff =
          1 - 0.5 * (distance / GameConfig.depotBlastRadius).clamp(0.0, 1.0);
      _damageLocal(
        tank,
        GameConfig.depotBlastDamage * falloff,
        ownerId,
        'depot-${depot.index}',
      );
    }
  }
}
