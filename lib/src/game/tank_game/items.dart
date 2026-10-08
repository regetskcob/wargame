part of '../tank_game.dart';

/// Crates, gems and the inventory, upgrades, smoke, mines, air strikes and artillery barrages.
extension TankGameItems on TankGame {
  /// Buys the next step of [kind] for the local tank.
  void buyUpgrade(UpgradeKind kind) {
    if (!(round?.defense ?? false)) {
      return;
    }
    final level = _level(kind);
    if (level >= GameConfig.upgradeLimit(extended: extended)) {
      showNotice(
        level >= GameConfig.upgradeMaxLevel
            ? tr('HÖCHSTE STUFE', 'MAXIMUM LEVEL')
            : tr(
                'STUFE ${level + 1} IN DER VERLÄNGERUNG',
                'LEVEL ${level + 1} IN THE EXTENSION',
              ),
      );
      return;
    }
    final cost = kind.costFrom(level);
    if (credits.value < cost) {
      showNotice(tr('ZU WENIG MITTEL', 'NOT ENOUGH FUNDS'));
      return;
    }
    credits.value -= cost;
    upgrades.value = {...upgrades.value, kind: level + 1};
    final tank = myTank;
    if (tank != null) {
      _applyUpgrades(tank);
      if (kind == UpgradeKind.magazine) {
        tank.setAmmo(tank.ammo + (tank.magazine - tank.ammo) ~/ 2);
      }
    }
    AudioService.play('go', volume: 0.5);
    showNotice(
      tr(
        '${kind.label} STUFE ${level + 1}',
        '${kind.label} LEVEL ${level + 1}',
      ),
    );
  }

  void _applyUpgrades(PlayerTank tank) {
    tank
      ..armorFactor = UpgradeKind.armor.factorAt(_level(UpgradeKind.armor))
      ..gunFactor = UpgradeKind.gun.factorAt(_level(UpgradeKind.gun))
      ..engineFactor = UpgradeKind.engine.factorAt(_level(UpgradeKind.engine))
      ..magazineFactor = UpgradeKind.magazine.factorAt(
        _level(UpgradeKind.magazine),
      );
    if (tank == myTank) {
      ammoNotifier.value = tank.ammo;
    }
  }

  void _updatePowerUps() {
    final activeRound = round;
    if (activeRound == null || phase.value == GamePhase.lobby) {
      return;
    }
    final elapsed =
        (DateTime.now().millisecondsSinceEpoch - activeRound.startedAt) / 1000;
    for (final slot in _powerUpSlots) {
      if (elapsed >= slot.appearsAt &&
          !_gone.contains(slot.id) &&
          !powerUps.containsKey(slot.id)) {
        final crate = PowerUp(slot: slot);
        powerUps[slot.id] = crate;
        _extras.add(crate);
        world.add(crate);
      }
    }
    smokes.removeWhere((cloud) => !cloud.isMounted && cloud.isLoaded);
    // Tanks inside a cloud vanish for everyone outside it. Spectators and
    // dead players see the whole field.
    final viewer = phase.value == GamePhase.playing ? myTank : null;
    final viewerInside =
        viewer == null || smokes.any((cloud) => cloud.covers(viewer.position));
    for (final tank in remoteTanks.values) {
      tank.hidden =
          viewer != null &&
          !viewerInside &&
          smokes.any((cloud) => cloud.covers(tank.position));
    }
  }

  /// [tank] drove over [crate]: the player's tank or a bot of this client.
  /// The player's crates and gems go into the inventory, CPU tanks use
  /// theirs on the spot.
  void collectPowerUp(PowerUp crate, PlayerTank tank) {
    final mine = tank == myTank;
    final live =
        phase.value == GamePhase.playing ||
        (!mine && phase.value == GamePhase.spectating);
    if (!live || tank.hp <= 0) {
      return;
    }
    final slot = crate.slot;
    if (_gone.contains(slot.id)) {
      return;
    }
    if (mine && !inventory.canTake(slot.type)) {
      if (notice.value == null) {
        showNotice(tr('INVENTAR VOLL', 'INVENTORY FULL'));
      }
      return;
    }
    // A CPU tank with a full inventory leaves the crate for others.
    if (!mine && !tank.items.canTake(slot.type)) {
      return;
    }
    _gone.add(slot.id);
    powerUps.remove(slot.id);
    crate.removeFromParent();
    net.send(
      NetEvent.pickup,
      PickupPayload(id: tank.playerId, powerUpId: slot.id).toJson(),
    );
    if (mine) {
      inventory.add(slot.type);
      AudioService.play('go', volume: 0.5);
      final key = inventory.value.indexWhere((s) => s.type == slot.type) + 1;
      showNotice('${slot.type.label}  [$key]');
    } else {
      tank.items.add(slot.type);
    }
  }

  /// A CPU tank sets off item [index] of its own inventory.
  void useBotItem(PlayerTank tank, int index) {
    if (tank.hp <= 0) {
      return;
    }
    final type = tank.items.take(index);
    if (type == null) {
      return;
    }
    _applyItem(tank, type);
    _calloutItem(tank.position, type);
    // Repair and rapid fire announce themselves already.
    if (type != PowerUpType.repair && type != PowerUpType.rapidFire) {
      net.send(
        NetEvent.use,
        UsePayload(id: tank.playerId, item: type.name).toJson(),
      );
    }
  }

  void _calloutItem(Vector2 at, PowerUpType type) {
    world.add(
      ItemCallout(
        position: at + Vector2(0, -GameConfig.tankRadius - 16),
        text: type.label,
        color: type.color,
      ),
    );
  }

  /// Sets off item [index] of the inventory with the local tank.
  void useItem(int index) {
    final tank = myTank;
    if (tank == null ||
        tank.hp <= 0 ||
        phase.value != GamePhase.playing ||
        index >= inventory.value.length) {
      return;
    }
    final type = inventory.take(index);
    if (type == null) {
      return;
    }
    _applyItem(tank, type);
    AudioService.play('go', volume: 0.4);
    showNotice(type.label);
  }

  /// What an item does, for the player's tank and for CPU tanks alike.
  void _applyItem(PlayerTank tank, PowerUpType type) {
    final mine = tank == myTank;
    switch (type) {
      case PowerUpType.repair:
        tank.hp = min(tank.stats.maxHp, tank.hp + GameConfig.repairAmount);
        if (mine) {
          hpNotifier.value = tank.hp;
        }
        _announceUse(tank, type);
      case PowerUpType.rapidFire:
        tank.rapidFireLeft = GameConfig.rapidFireSeconds;
        if (mine) {
          rapidFireSeconds.value = GameConfig.rapidFireSeconds.ceil();
        }
        _announceUse(tank, type);
      case PowerUpType.ammo:
        tank.setAmmo(
          tank.ammo + (tank.magazine * GameConfig.ammoRefillShare).ceil(),
        );
      case PowerUpType.grenades || PowerUpType.drone || PowerUpType.mortar:
        tank.arm(type.weapon!);
      case PowerUpType.smoke:
        _throwSmoke(tank);
      case PowerUpType.shield:
        tank
          ..shieldLeft = GameConfig.shieldSeconds
          ..shielded = true;
        if (mine) {
          shieldSeconds.value = GameConfig.shieldSeconds.ceil();
        }
      case PowerUpType.mines:
        _layMines(tank);
      case PowerUpType.artillery:
        _callArtillery(tank);
      case PowerUpType.infantry:
        _deploySquad(tank, para: false);
      case PowerUpType.paratroopers:
        _deploySquad(tank, para: true);
      case PowerUpType.fuel:
        tank.setFuel(tank.fuel + GameConfig.canisterShare);
      case PowerUpType.hunterDrone:
        _launchHunter(tank);
      case PowerUpType.airstrike:
        _callAirstrike(tank);
    }
  }

  /// A drone from the inventory: off it goes after an enemy picked at
  /// random, wherever that one is.
  void _launchHunter(PlayerTank tank) {
    final enemies = enemiesOf(tank.playerId).toList();
    final prey = enemies.isEmpty
        ? null
        : enemies[random.nextInt(enemies.length)].playerId;
    final droneId = '${tank.playerId}-d${_bulletCounter++}';
    final drone = Drone(
      droneId: droneId,
      ownerId: tank.playerId,
      color: tank.tankColor,
      position: tank.position + tank.turretDirection * 30,
      angle: tank.turretAngle,
      preyId: prey,
      life: GameConfig.enemyDroneSeconds,
    );
    drones[droneId] = drone;
    _extras.add(drone);
    world.add(drone);
    if (tank == myTank && prey != null) {
      showNotice(
        tr(
          'JAGDDROHNE AUF ${_nameOf(prey).toUpperCase()}',
          'HUNTER DRONE ON ${_nameOf(prey).toUpperCase()}',
        ),
      );
    }
  }

  /// A bomber crosses the field and drops a string of bombs on the enemy
  /// closest to where the player aims, leading it a little.
  void _callAirstrike(PlayerTank tank) {
    final aim = _aimPoint(tank, GameConfig.airstrikeReach);
    TankBase? prey;
    var best = double.infinity;
    for (final enemy in enemiesOf(tank.playerId)) {
      final distance = enemy.position.distanceTo(aim);
      if (distance < best) {
        best = distance;
        prey = enemy;
      }
    }
    final target = prey == null ? aim : prey.position + velocityOf(prey) * 1.4;
    final heading = Vector2(
      cos(random.nextDouble() * 2 * pi),
      sin(random.nextDouble() * 2 * pi),
    );
    final from = target - heading * 1400;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < GameConfig.airstrikeBombs; i++) {
      final at =
          target + heading * ((i - (GameConfig.airstrikeBombs - 1) / 2) * 60);
      final payload = ArtilleryPayload(
        id: tank.playerId,
        strikeId: '${tank.playerId}-j${_specialCounter++}',
        x: at.x,
        y: at.y,
        at: now + 1400 + i * 140,
        jetX: i == 0 ? from.x : null,
        jetY: i == 0 ? from.y : null,
      );
      _addArtillery(payload);
      net.send(NetEvent.artillery, payload.toJson());
    }
    if (tank == myTank) {
      showNotice(
        prey == null
            ? tr('LUFTSCHLAG', 'AIR STRIKE')
            : tr(
                'LUFTSCHLAG AUF ${_nameOf(prey.playerId).toUpperCase()}',
                'AIR STRIKE ON ${_nameOf(prey.playerId).toUpperCase()}',
              ),
      );
    }
  }

  /// Repairs and rapid fire change what the others accept from this tank,
  /// so they hear about it.
  void _announceUse(PlayerTank tank, PowerUpType type) {
    net.send(
      NetEvent.use,
      UsePayload(id: tank.playerId, item: type.name).toJson(),
    );
  }

  void _onUse(UsePayload payload) {
    final type = PowerUpType.values.asNameMap()[payload.item];
    final bot = remoteTanks[payload.id];
    if (type != null && bot != null && (round?.isBot(payload.id) ?? false)) {
      _calloutItem(bot.position, type);
    }
    switch (type) {
      case PowerUpType.repair:
        guard.allowRepair(payload.id);
      case PowerUpType.rapidFire:
        guard.allowRapidFire(payload.id);
      case _:
    }
  }

  /// Where the local player points: the mouse, or ahead of the turret at
  /// [reach] for touch controls and CPU tanks. Never further than [reach].
  Vector2 _aimPoint(PlayerTank tank, double reach) {
    // A CPU tank aims as far as its target is.
    if (tank.isBot) {
      reach = min(reach, tank.input.lobDistance ?? reach);
    }
    var target = tank.isBot || touch.aim != null
        ? tank.position + tank.turretDirection * reach
        : pointerWorld() ?? tank.position + tank.turretDirection * reach;
    final offset = target - tank.position;
    if (offset.length > reach) {
      target = tank.position + offset.normalized() * reach;
    }
    return target;
  }

  /// A smoke grenade: thrown ahead and the cloud rises where it lands. CPU
  /// tanks hide where they stand.
  void _throwSmoke(PlayerTank tank) {
    final to = tank.isBot
        ? tank.position.clone()
        : _aimPoint(tank, GameConfig.smokeThrowRange);
    final from = tank.position.clone();
    net.send(
      NetEvent.smoke,
      SmokePayload(
        id: tank.playerId,
        x: to.x,
        y: to.y,
        fromX: tank.isBot ? null : from.x,
        fromY: tank.isBot ? null : from.y,
      ).toJson(),
    );
    if (tank.isBot) {
      _addSmoke(to);
    } else {
      _lobSmoke(tank.playerId, from, to);
    }
  }

  void _lobSmoke(String ownerId, Vector2 from, Vector2 to) {
    final grenade = Grenade(
      grenadeId: '$ownerId-s${_specialCounter++}',
      ownerId: ownerId,
      from: from,
      to: to,
      onLand: _addSmoke,
    );
    _extras.add(grenade);
    world.add(grenade);
  }

  void _addSmoke(Vector2 at) {
    final cloud = SmokeCloud(position: at);
    smokes.add(cloud);
    _extras.add(cloud);
    world.add(cloud);
  }

  void _onPickup(PickupPayload payload) {
    if (_gone.contains(payload.powerUpId)) {
      return;
    }
    switch (_slotOf(payload.powerUpId)?.type) {
      case PowerUpType.mines ||
          PowerUpType.artillery ||
          PowerUpType.infantry ||
          PowerUpType.paratroopers:
        guard.allowSpecial(payload.id);
      case PowerUpType.airstrike:
        for (var i = 0; i < GameConfig.airstrikeBombs; i++) {
          guard.allowSpecial(payload.id);
        }
      case _:
    }
    _gone.add(payload.powerUpId);
    powerUps.remove(payload.powerUpId)?.removeFromParent();
  }

  PowerUpSlot? _slotOf(int id) {
    for (final slot in _powerUpSlots) {
      if (slot.id == id) {
        return slot;
      }
    }
    return null;
  }

  void _onSmoke(SmokePayload payload) {
    if (round == null) {
      return;
    }
    final to = Vector2(payload.x, payload.y);
    final fromX = payload.fromX;
    final fromY = payload.fromY;
    if (fromX != null && fromY != null) {
      _lobSmoke(payload.id, Vector2(fromX, fromY), to);
    } else {
      _addSmoke(to);
    }
  }

  /// Drops a small fan of mines behind [tank].
  void _layMines(PlayerTank tank) {
    final back = -tank.direction;
    final side = Vector2(-back.y, back.x);
    final spots = [
      tank.position + back * 46 + side * 30,
      tank.position + back * 46 - side * 30,
      tank.position + back * 80,
    ].take(GameConfig.minesPerCrate);
    final owner = tank.playerId;
    final laid = [
      for (final spot in spots)
        (id: '$owner-m${_specialCounter++}', x: spot.x, y: spot.y),
    ];
    for (final mine in laid) {
      _addMine(mine.id, owner, Vector2(mine.x, mine.y));
    }
    net.send(NetEvent.mine, MinePayload(id: owner, mines: laid).toJson());
  }

  void _addMine(String mineId, String ownerId, Vector2 at) {
    if (mines.containsKey(mineId)) {
      return;
    }
    final mine = Mine(
      mineId: mineId,
      ownerId: ownerId,
      friendly: ownerId == myId || isTeammate(ownerId),
      position: at,
    );
    mines[mineId] = mine;
    _extras.add(mine);
    world.add(mine);
  }

  void _onMine(MinePayload payload) {
    if (round?.alive.contains(payload.id) != true ||
        !guard.allowSpecial(payload.id, consume: true)) {
      return;
    }
    for (final mine in payload.mines.take(GameConfig.minesPerCrate)) {
      _addMine(mine.id, payload.id, Vector2(mine.x, mine.y));
    }
  }

  /// [tank], run by this client, drove onto an enemy mine.
  void triggerMine(Mine mine, PlayerTank tank) {
    if (mines.remove(mine.mineId) == null) {
      return;
    }
    mineBlast(this, mine.position.clone());
    mine.removeFromParent();
    AudioService.play('explosion', distance: _distanceToView(mine.position));
    _damageLocal(tank, GameConfig.mineDamage, mine.ownerId, mine.mineId);
  }

  /// Calls a barrage onto the mouse cursor, or ahead of the turret when
  /// there is no mouse, at most [GameConfig.artilleryRange] away.
  void _callArtillery(PlayerTank tank) {
    final target = _aimPoint(tank, GameConfig.artilleryRange);
    final payload = ArtilleryPayload(
      id: tank.playerId,
      strikeId: '${tank.playerId}-a${_specialCounter++}',
      x: target.x,
      y: target.y,
      at:
          DateTime.now().millisecondsSinceEpoch +
          (GameConfig.artilleryDelay * 1000).round(),
    );
    _addArtillery(payload);
    net.send(NetEvent.artillery, payload.toJson());
  }

  void _addArtillery(ArtilleryPayload payload) {
    final jetX = payload.jetX;
    final jetY = payload.jetY;
    if (jetX != null && jetY != null) {
      final jet = StrikeJet(
        from: Vector2(jetX, jetY),
        over: Vector2(payload.x, payload.y),
        at: payload.at,
      );
      _extras.add(jet);
      world.add(jet);
      AudioService.play('go', volume: 0.4);
    }
    final strike = ArtilleryStrike(
      strikeId: payload.strikeId,
      ownerId: payload.id,
      at: payload.at,
      position: Vector2(payload.x, payload.y),
    );
    _extras.add(strike);
    world.add(strike);
    AudioService.play('tick', distance: _distanceToView(strike.position));
  }

  void _onArtillery(ArtilleryPayload payload) {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Never further out than the delay, and never long past.
    final late = payload.at - now;
    if (late > GameConfig.artilleryDelay * 1000 + 1000 || late < -1000) {
      return;
    }
    // Bombs of enemy jets come from the player who runs the enemies.
    final bombs = round?.isEnemy(payload.id) ?? false;
    if (!bombs &&
        (round?.alive.contains(payload.id) != true ||
            !guard.allowSpecial(payload.id, consume: true))) {
      return;
    }
    _addArtillery(payload);
  }

  /// The shells of [strike] land: hurt the tanks this client runs, and let
  /// the caller's client knock down what stands in the circle.
  void artilleryImpact(ArtilleryStrike strike) {
    AudioService.play('explosion', distance: _distanceToView(strike.position));
    final tanks = <PlayerTank>[...botTanks.values];
    final mine = myTank;
    if (mine != null) tanks.insert(0, mine);
    for (final tank in tanks) {
      if (tank.playerId == strike.ownerId ||
          sameTeam(tank.playerId, strike.ownerId)) {
        continue;
      }
      final distance = tank.position.distanceTo(strike.position);
      if (distance > GameConfig.artilleryRadius + GameConfig.tankRadius) {
        continue;
      }
      final falloff =
          1 - 0.5 * (distance / GameConfig.artilleryRadius).clamp(0.0, 1.0);
      _damageLocal(
        tank,
        strike.damage * falloff,
        strike.ownerId,
        strike.strikeId,
      );
    }
    // The player who runs the waves keeps the score of the bases, also of
    // a strike the other player of a duel called in.
    if (round?.botHost == myId) {
      for (final base in _defenseField?.bases ?? const <Headquarters>[]) {
        if (hurtsBase(strike.ownerId, base.lane) &&
            base.position.distanceTo(strike.position) <
                GameConfig.artilleryRadius + DefenseMap.baseRadius) {
          damageBase(strike.damage, lane: base.lane);
        }
      }
      _blastTowers(
        strike.ownerId,
        strike.position,
        GameConfig.artilleryRadius,
        strike.damage,
      );
    }
    if (runsShooter(strike.ownerId)) {
      _blastSoldiers(
        strike.ownerId,
        strike.position,
        GameConfig.artilleryRadius,
      );
      for (final obstacle in [
        ...?_coverField?.obstacles,
        ...?_defenseField?.obstacles,
      ]) {
        if (obstacle.hp > 0 &&
            obstacle.position.distanceTo(strike.position) <
                GameConfig.artilleryRadius) {
          damageObstacle(obstacle, strike.damage);
        }
      }
      for (final tree in [...?_coverField?.trees, ...?_defenseField?.trees]) {
        if (!tree.felled &&
            tree.position.distanceTo(strike.position) <
                GameConfig.artilleryRadius) {
          damageTree(tree, tree.maxHp);
        }
      }
    }
  }
}
