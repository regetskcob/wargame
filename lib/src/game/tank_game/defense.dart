part of '../tank_game.dart';

/// The defense mode: setting up the base, enemy waves and allies, the base and its growth, the decision after the last wave, and the guns.
extension TankGameDefense on TankGame {
  /// The fixed map of a defense round: road, base and the players in front
  /// of it. The player who runs the enemies also gets the director.
  void _setUpDefense(RoundState activeRound) {
    final map = activeRound.duel
        ? DefenseMap.duelForSeed(activeRound.seed)
        : DefenseMap.forSeed(activeRound.seed);
    defenseMap = map;
    final field = DefenseField(seed: activeRound.seed, map: map);
    _defenseField = field;
    _setGround(field.theme, plain: true);
    conditions = Conditions.at(activeRound.seed, 0, field.theme);
    conditionsLabel.value = conditions!.label;
    _weather = WeatherLayer(conditions!);
    world.add(field);
    _fitCamera();
    // The screenshot mode brings funds for a row of guns, see Env.shots.
    credits.value = Env.shots ? 2000 : GameConfig.startCredits;
    _towerCounter = 0;
    _enemyGunCounter = 0;
    guard.worldReach = DefenseMap.bounds.bottomRight.distance;
    _powerUpSlots = PowerUpSlot.scheduleDefense(
      activeRound.seed,
      map,
      activeRound.botLevel,
    );
    _raiseTerrain(
      activeRound,
      field.theme,
      area: DefenseMap.bounds,
      keepClear: map.bases,
    );
    soldierField = SoldierField(
      seed: activeRound.seed,
      startedAt: activeRound.startedAt,
      seeded: false,
      onArrive: _soldierArrived,
    );
    _extras.add(soldierField!);
    world.add(soldierField!);
    defense.value = DefensePayload(
      id: activeRound.botHost ?? '',
      hp: GameConfig.baseHp,
      hp2: activeRound.duel ? GameConfig.baseHp : null,
      wave: 0,
      nextWaveAt: activeRound.startedAt + GameConfig.firstWaveSeconds * 1000,
    );
    final players = activeRound.participants;
    for (var i = 0; i < players.length; i++) {
      final id = players[i];
      // In a duel everybody starts at the base of their side.
      final lane = map.lanes[activeRound.laneOf(id) % map.lanes.length];
      final side = [
        for (final other in players)
          if (activeRound.laneOf(other) == activeRound.laneOf(id)) other,
      ];
      final spawn = lane.spawnFor(side.indexOf(id), side.length);
      final facing = TankGame._headingFrom(
        spawn,
        lane.road[lane.road.length - 2],
      );
      if (id == myId) {
        _spawnLocalTank(spawn, facing);
      } else {
        _addRemoteTank(id, spawn, facing);
      }
    }
    if (activeRound.botHost == myId) {
      final director = DefenseDirector(
        startedAt: activeRound.startedAt,
        // A duel is fought by the two players alone.
        allies: activeRound.duel
            ? 0
            : max(1, GameConfig.defenseSquad - players.length),
      );
      _extras.add(director);
      world.add(director);
    }
    // Two players on this screen watch their duel on one map.
    overview.value = activeRound.duel && localGuest;
    _fitCamera();
    _enterRound(activeRound);
  }

  /// The side the local player defends in a duel, else the only one.
  int get myLane => round?.laneOf(myId) ?? 0;

  /// The road and base of [lane], the only ones outside a duel.
  DefenseMap? laneMap(int lane) {
    final map = defenseMap;
    return map?.lanes[lane.clamp(0, map.lanes.length - 1)];
  }

  /// The local player's road and base.
  DefenseMap? get myLaneMap => laneMap(myLane);

  /// Host of a defense round: an enemy rolls in at the start of the road of
  /// [lane]. A troop a player sent fights for the side of [team].
  void spawnEnemy(String id, {int lane = 0, int team = 2}) {
    final activeRound = round;
    final map = laneMap(lane);
    if (activeRound == null || map == null) {
      return;
    }
    final style = activeRound.enemyStyle(id);
    final controls = TouchInput();
    // In a duel the road starts at the other side's base: out in front of
    // it, not in it.
    final (at, _) = map.duel
        ? map.alongRoad(DefenseMap.baseRadius + 40)
        : (map.entry, map.road[1]);
    final tank =
        PlayerTank(
            playerId: id,
            playerName: activeRound.botName(id),
            tankColor: _colorFor(id),
            tankType: GameConfig.typeOf(style),
            position: at.clone(),
            angle: TankGame._headingFrom(at, map.road[1]),
            controls: controls,
          )
          ..team = team
          ..endlessAmmo = true
          ..speedFactor = GameConfig.enemySpeed
          ..fireFactor = GameConfig.enemyFireFactor
          ..armorFactor = GameConfig.enemyArmorIn(defense.value?.wave ?? 0)
          ..syncInterval = GameConfig.enemySyncInterval;
    activeRound.alive.add(id);
    aliveCount.value = activeRound.alive.length;
    botTanks[id] = tank;
    world.add(tank);
    final brain = DefenseBrain(
      tank: tank,
      controls: controls,
      map: map,
      lane: lane,
    );
    _extras.add(brain);
    world.add(brain);
  }

  /// Host of a defense round: a CPU comrade rolls out of the base to the
  /// post of [slot].
  void spawnAlly(String id, int slot) {
    final activeRound = round;
    final map = defenseMap;
    if (activeRound == null || map == null) {
      return;
    }
    final style = activeRound.allyStyle(id);
    final route = map.allyRoute(slot);
    final at =
        map.base +
        (route.first - map.base).normalized() * (DefenseMap.baseRadius + 30);
    final controls = TouchInput();
    final tank =
        PlayerTank(
            playerId: id,
            playerName: activeRound.botName(id),
            tankColor: _colorFor(id),
            tankType: GameConfig.typeOf(style),
            position: at,
            angle: TankGame._headingFrom(at, route.first),
            controls: controls,
          )
          ..team = 1
          ..endlessAmmo = true
          ..syncInterval = GameConfig.enemySyncInterval;
    activeRound.alive.add(id);
    aliveCount.value = activeRound.alive.length;
    botTanks[id] = tank;
    world.add(tank);
    final brain = AllyBrain(
      tank: tank,
      controls: controls,
      map: map,
      slot: slot,
    );
    _extras.add(brain);
    world.add(brain);
  }

  /// Host: enemy tanks of the current wave still on the field.
  int get enemiesAlive {
    final activeRound = round;
    if (activeRound == null) {
      return 0;
    }
    return botTanks.keys.where(activeRound.isEnemy).length;
  }

  /// Host of a defense round: a squad on foot marches in down the road.
  void spawnEnemySquad(String id, int wave, {int lane = 0}) {
    final map = laneMap(lane);
    if (map == null) {
      return;
    }
    _addSquad(
      SquadPayload(
        id: myId,
        owner: id,
        squad: id,
        x: map.entry.x,
        y: map.entry.y,
        at: DateTime.now().millisecondsSinceEpoch,
        rifles: 4,
        rockets: wave >= 3 ? 1 : 0,
        road: true,
        lane: lane,
      ),
      send: true,
    );
  }

  /// Host of a defense round: the base sends [count] squads on foot up the
  /// road against wave [wave], a few seconds apart. They hold a line and
  /// fight what comes.
  void spawnBaseSquads(int wave, int count, {int lane = 0}) {
    final map = laneMap(lane);
    if (map == null) {
      return;
    }
    final duel = round?.duel ?? false;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < count; i++) {
      // In a duel the infantry fights for the side of its base.
      final id = duel ? 'ally-L$lane-q$wave-$i' : 'ally-q$wave-$i';
      _addSquad(
        SquadPayload(
          id: myId,
          owner: id,
          squad: id,
          x: map.base.x,
          y: map.base.y,
          at: now + i * 4000,
          rifles: GameConfig.squadRifles,
          rockets: count >= 3 ? 2 : 1,
          road: true,
          back: true,
          lane: lane,
        ),
        send: true,
      );
    }
    if (lane == myLane) {
      showNotice(tr('EIGENE INFANTERIE RÜCKT AUS', 'OWN INFANTRY MOVING OUT'));
    }
  }

  /// Enemies of a defense round on the field: tanks, aircraft and soldiers.
  int get enemiesOnField {
    final activeRound = round;
    if (activeRound == null) {
      return 0;
    }
    return activeRound.alive.where(activeRound.isEnemy).length +
        aircraft.values.where((plane) => !plane.friendly).length +
        (soldierField?.all
                .where(
                  (s) =>
                      !s.dead &&
                      s.isMounted &&
                      activeRound.isEnemy(s.ownerId ?? ''),
                )
                .length ??
            0);
  }

  /// Whether anything of the current wave is still out there.
  bool get enemyForcesLeft {
    final activeRound = round;
    if (activeRound == null) {
      return false;
    }
    return botTanks.keys.any(activeRound.isEnemy) ||
        aircraft.values.any((plane) => !plane.remote && !plane.friendly) ||
        drones.values.any(
          (drone) => !drone.remote && activeRound.isEnemy(drone.ownerId),
        ) ||
        (soldierField?.all.any(
              (s) => !s.dead && activeRound.isEnemy(s.ownerId ?? ''),
            ) ??
            false);
  }

  /// Host: an enemy made it to the base and blows itself up there.
  void raidBase(PlayerTank enemy, {int lane = 0}) {
    if (enemy.hp <= 0) {
      return;
    }
    damageBase(GameConfig.raidDamage * enemy.stats.maxHp / 100, lane: lane);
    enemy.applyDamage(enemy.hp, killerId: null);
  }

  /// Host: enemy fire or a raid wore the base of [lane] down.
  void damageBase(double amount, {int lane = 0}) {
    final state = defense.value;
    if (state == null || round?.botHost != myId) {
      return;
    }
    publishDefense(
      state.withBase(lane, hp: max(0.0, state.hpOf(lane) - amount)),
    );
  }

  /// Whether a shot of [ownerId] wears down a gun of [towerOwner]: in a
  /// common round the enemy's shots the players' guns and the defenders'
  /// shots the enemy's, the other side's and the waves' in a duel.
  bool hurtsTower(String ownerId, String towerOwner) {
    final activeRound = round;
    if (activeRound == null) {
      return false;
    }
    if (!activeRound.duel) {
      return ownerId.isNotEmpty &&
          activeRound.isEnemy(ownerId) != activeRound.isEnemy(towerOwner);
    }
    final team = activeRound.teamOf(ownerId);
    return team != 0 && team != activeRound.teamOf(towerOwner);
  }

  /// Whether a shot of [ownerId] hurts the base of [lane]: the enemy's in a
  /// common round, the other side's and the waves' in a duel.
  bool hurtsBase(String ownerId, int lane) {
    final activeRound = round;
    if (activeRound == null) {
      return false;
    }
    if (!activeRound.duel) {
      return activeRound.isEnemy(ownerId);
    }
    final team = activeRound.teamOf(ownerId);
    return team != 0 && team != lane + 1;
  }

  /// Whether the defenders went on past the last regular wave.
  bool get extended => defense.value?.extended ?? false;

  /// Host, after the last wave of a stretch: another
  /// [GameConfig.defenseExtension] waves.
  void extendDefense() {
    final state = defense.value;
    if (state == null || round?.botHost != myId || !state.canExtend) {
      return;
    }
    publishDefense(
      state.copyWith(
        extended: true,
        until: state.wave + GameConfig.defenseExtension,
        nextWaveAt:
            DateTime.now().millisecondsSinceEpoch +
            GameConfig.waveBreakSeconds * 1000,
      ),
    );
  }

  /// Whether the host may let the next wave roll now: during a break, but
  /// not while the extension is up for decision.
  bool get canCallWave {
    final state = defense.value;
    return state != null &&
        round?.botHost == myId &&
        state.result == DefenseResult.running &&
        state.nextWaveAt > DateTime.now().millisecondsSinceEpoch + 1000 &&
        !state.deciding;
  }

  /// Host: the next wave rolls at once instead of after the break. The
  /// play test counted some 95 s of waiting in a full defense round, most
  /// of it with nothing left to build.
  void callWaveNow() {
    if (!canCallWave) {
      return;
    }
    publishDefense(
      defense.value!.copyWith(
        nextWaveAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Whether the win is safe, so that ending the round now counts as one:
  /// after the regular waves, and all through an extension.
  bool get defenseWonAlready {
    final state = defense.value;
    return state != null &&
        !state.duel &&
        state.result == DefenseResult.running &&
        (state.deciding || state.extended);
  }

  /// Host, once the win is safe: end the round as a win, also in the middle
  /// of a wave, so the round never has to be left without its win.
  void withdrawDefense() {
    final state = defense.value;
    if (state == null || round?.botHost != myId || !defenseWonAlready) {
      return;
    }
    publishDefense(state.copyWith(result: DefenseResult.won));
  }

  /// Host: applies a new state of the base and the waves and sends it.
  void publishDefense(DefensePayload state) {
    _applyDefense(state);
    net.send(NetEvent.defense, state.toJson());
  }

  void _onDefense(DefensePayload payload) {
    final activeRound = round;
    // Only the player who runs the waves says how the base stands.
    if (activeRound != null &&
        activeRound.defense &&
        payload.id == activeRound.botHost &&
        !net.duplicateIds.contains(payload.id)) {
      _applyDefense(payload);
    }
  }

  void _applyDefense(DefensePayload state) {
    final before = defense.value;
    for (final base in _defenseField?.bases ?? const <Headquarters>[]) {
      final hp = state.hpOf(base.lane);
      if (before != null && hp < before.hpOf(base.lane)) {
        base.flash();
        shakeAt(base.position, 4);
        AudioService.play(
          'hit',
          volume: 0.8,
          distance: _distanceToView(base.position),
        );
      }
      base
        ..hp = hp
        ..level = state.hqOf(base.lane);
    }
    defense.value = state;
    // In a duel only the own base's growth is news.
    final lane = myLane;
    if (before != null && state.hqOf(lane) > before.hqOf(lane)) {
      final hq = state.hqOf(lane);
      showNotice(
        tr(
          'STÜTZPUNKT AUSGEBAUT: ${GameConfig.hqName(hq)}  '
              '+${GameConfig.hqTowerStep} GESCHÜTZE',
          'BASE UPGRADED: ${GameConfig.hqName(hq)}  '
              '+${GameConfig.hqTowerStep} TURRETS',
        ),
      );
      AudioService.play('win', volume: 0.5);
    }
    final until = state.until;
    if (before != null && until != null && until != before.until) {
      showNotice(
        before.extended
            ? tr('VERLÄNGERT BIS WELLE $until', 'EXTENDED TO WAVE $until')
            : tr(
                'VERLÄNGERT BIS WELLE $until: STUFE 4 UND 5, RAKETENWERFER',
                'EXTENDED TO WAVE $until: LEVELS 4 AND 5, ROCKET LAUNCHERS',
              ),
      );
      AudioService.play('go', volume: 0.6);
    } else if (before != null && state.extended && !before.extended) {
      // An older host extends without an end.
      showNotice(
        tr(
          'VERLÄNGERUNG: STUFE 4 UND 5, RAKETENWERFER',
          'EXTENSION: LEVELS 4 AND 5, ROCKET LAUNCHERS',
        ),
      );
      AudioService.play('go', volume: 0.6);
    }
    if (before != null &&
        state.wave > 0 &&
        state.nextWaveAt > 0 &&
        before.nextWaveAt == 0) {
      // A wave was beaten off.
      credits.value += GameConfig.waveBonus;
      showNotice(
        state.deciding || state.result == DefenseResult.won
            ? tr(
                'ALLE ${state.wave} WELLEN ABGEWEHRT  +${GameConfig.waveBonus}',
                'ALL ${state.wave} WAVES REPELLED  +${GameConfig.waveBonus}',
              )
            : tr(
                'WELLE ${state.wave} ABGEWEHRT  +${GameConfig.waveBonus}',
                'WAVE ${state.wave} REPELLED  +${GameConfig.waveBonus}',
              ),
      );
    } else if (before != null && state.wave > before.wave) {
      showNotice(
        tr('WELLE ${state.wave} ROLLT AN', 'WAVE ${state.wave} INCOMING'),
      );
      AudioService.play('go', volume: 0.6);
    }
    if (state.result != DefenseResult.running) {
      // A duel is won by the side whose base still stands.
      _endDefense(
        won: state.duel
            ? state.fell != myLane && state.fell != 2
            : state.result == DefenseResult.won,
      );
    }
  }

  /// Puts the chosen gun where the local tank stands, if there is money and
  /// room. Next to one of the player's own guns it upgrades that one
  /// instead.
  void buildTower([TowerKind? kind]) {
    final tank = myTank;
    final map = defenseMap;
    if (tank == null || map == null || phase.value != GamePhase.playing) {
      return;
    }
    final near = _ownTowerAt(tank.position);
    if (kind == null && near != null) {
      upgradeTower(near);
      return;
    }
    final build = kind ?? towerChoice.value;
    towerChoice.value = build;
    final mine = towers.values
        .where(
          (t) => t.ownerId == myId && !t.isHq && t.kind.isGun == build.isGun,
        )
        .length;
    final limit = build.isGun ? towerLimit : GameConfig.maxTrenches;
    final locked = build.lockedIn(defense.value?.wave ?? 0, extended: extended);
    final cost = buildCost(build);
    final reason = locked != null
        ? '${build.label} $locked'
        : credits.value < cost
        ? tr('Zu wenig Mittel', 'Not enough funds')
        : mine >= limit
        ? build.isGun
              ? tr('Höchstens $limit Geschütze', 'At most $limit turrets')
              : tr('Höchstens $limit Gräben', 'At most $limit trenches')
        : map.whyNotBuild(
            tank.position,
            towers.values.map((t) => t.position),
            onRoad: !build.isGun,
          );
    if (reason != null) {
      showNotice(reason.toUpperCase());
      return;
    }
    credits.value -= cost;
    final payload = TowerPayload(
      id: myId,
      index: _towerCounter++,
      x: tank.position.x,
      y: tank.position.y,
      kind: build.index,
    );
    _addTower(payload);
    net.send(NetEvent.tower, payload.toJson());
    AudioService.play('go', volume: 0.5);
  }

  /// A defense duel: pays for a tank that rolls down the other side's road
  /// against its base. The player who runs the waves sends it.
  void sendTroops() {
    final activeRound = round;
    if (activeRound == null ||
        !activeRound.duel ||
        phase.value != GamePhase.playing) {
      return;
    }
    if (credits.value < GameConfig.troopCost) {
      showNotice(tr('ZU WENIG MITTEL', 'NOT ENOUGH FUNDS'));
      return;
    }
    credits.value -= GameConfig.troopCost;
    final payload = TroopsPayload(id: myId, serial: _troopCounter++);
    if (activeRound.botHost == myId) {
      _launchTroops(payload);
    } else {
      net.send(NetEvent.troops, payload.toJson());
    }
    showNotice(tr('PANZER IN MARSCH', 'TANK ON ITS WAY'));
    AudioService.play('go', volume: 0.5);
  }

  void _onTroops(TroopsPayload payload) {
    final activeRound = round;
    // Only a player of the duel sends troops, and only the player who runs
    // the waves sends them on their way.
    if (activeRound == null ||
        !activeRound.duel ||
        activeRound.botHost != myId ||
        !activeRound.lanes.contains(payload.id) ||
        net.duplicateIds.contains(payload.id)) {
      return;
    }
    _launchTroops(payload);
  }

  void _launchTroops(TroopsPayload payload) {
    final activeRound = round;
    if (activeRound == null) {
      return;
    }
    final from = activeRound.laneOf(payload.id);
    final wave = max(1, defense.value?.wave ?? 1);
    final tag = payload.id.length > 4 ? payload.id.substring(0, 4) : payload.id;
    spawnEnemy(
      'td-s$from-$wave-$tag${payload.serial}',
      lane: 1 - from,
      team: from + 1,
    );
  }

  /// Whether a gun or trench of [kind] could go up now as far as the funds,
  /// the wave and the limit go; where the tank stands is for the build to
  /// say.
  bool canAffordTower(TowerKind kind) {
    if (!kind.unlockedIn(defense.value?.wave ?? 0, extended: extended) ||
        credits.value < buildCost(kind)) {
      return false;
    }
    final mine = towers.values
        .where(
          (t) => t.ownerId == myId && !t.isHq && t.kind.isGun == kind.isGun,
        )
        .length;
    return mine < (kind.isGun ? towerLimit : GameConfig.maxTrenches);
  }

  /// Whether the own gun next to the tank can go up a level now.
  bool get canAffordNearTower {
    final near = nearTower.value;
    return near != null &&
        near.kind.upgradable &&
        near.level < TowerKind.levelLimit(extended: extended) &&
        credits.value >= near.kind.upgradeCost(near.level);
  }

  /// Whether the next step of [kind] for the own tank is within the funds.
  bool canAffordUpgrade(UpgradeKind kind) {
    final level = _level(kind);
    return level < GameConfig.upgradeLimit(extended: extended) &&
        credits.value >= kind.costFrom(level);
  }

  /// Something to build or a gun to upgrade, for the dot on the guns button.
  bool get anyTowerAffordable =>
      canAffordNearTower || TowerKind.values.any(canAffordTower);

  /// An upgrade for the tank, for the dot on the upgrades button.
  bool get anyUpgradeAffordable => UpgradeKind.values.any(canAffordUpgrade);

  /// B builds this kind of gun next.
  void cycleTowerKind() {
    if (defenseMap == null) {
      return;
    }
    final wave = defense.value?.wave ?? 0;
    var next = towerChoice.value;
    for (var i = 0; i < TowerKind.values.length; i++) {
      next = TowerKind.values[(next.index + 1) % TowerKind.values.length];
      if (next.unlockedIn(wave, extended: extended)) {
        break;
      }
    }
    towerChoice.value = next;
    showNotice('${next.label} ${buildCost(next)}');
  }

  /// What the next gun or trench of [kind] costs the local player: every
  /// one of the same kind they already have makes it dearer.
  int buildCost(TowerKind kind) {
    final owned = towers.values
        .where((t) => t.ownerId == myId && !t.isHq && t.kind == kind)
        .length;
    return (kind.cost * (1 + GameConfig.towerCostStep * owned)).round();
  }

  /// How many guns a player may have: more as the base grows.
  int get towerLimit =>
      GameConfig.maxTowers +
      GameConfig.hqTowerStep * ((defense.value?.hqOf(myLane) ?? 1) - 1);

  /// Host: the base grew to [level] and gets guns of its own, a cannon on
  /// the barracks and flak on the fortress besides.
  void armBase(int level, {int lane = 0}) {
    final map = laneMap(lane);
    final activeRound = round;
    if (map == null || activeRound == null) {
      return;
    }
    // In a duel the guns of a base belong to the player of its side, and
    // fight for that side.
    final owner = activeRound.duel ? activeRound.lanes[lane] : myId;
    final guns = [
      if (level >= 2)
        (Tower.hqIndex, TowerKind.cannon, map.base, min(level - 1, 3)),
      if (level >= 3)
        (
          Tower.hqIndex + 1,
          TowerKind.flak,
          map.base + Vector2(-34, 30),
          level - 2,
        ),
      if (level >= 4)
        (Tower.hqIndex + 2, TowerKind.rockets, map.base + Vector2(34, 30), 1),
    ];
    for (final (index, kind, at, gunLevel) in guns) {
      final payload = TowerPayload(
        id: owner,
        index: index,
        x: at.x,
        y: at.y,
        kind: kind.index,
        level: gunLevel,
      );
      _addTower(payload);
      net.send(NetEvent.tower, payload.toJson());
    }
  }

  /// Host: enemy fire hit [tower] for [damage]. Everybody learns how much
  /// is left, at nothing it is gone.
  void damageTower(Tower tower, double damage) {
    if (round?.botHost != myId || tower.isHq || !tower.isMounted) {
      return;
    }
    tower
      ..hp -= damage
      ..hit();
    net.send(
      NetEvent.tower,
      TowerPayload(
        id: tower.ownerId,
        index: tower.index,
        x: tower.position.x,
        y: tower.position.y,
        kind: tower.kind.index,
        level: tower.level,
        hp: max(0, tower.hp),
      ).toJson(),
    );
    if (tower.hp <= 0) {
      _destroyTower(tower);
    }
  }

  void _destroyTower(Tower tower) {
    if (towers.remove(tower.id) == null) {
      return;
    }
    world.add(Explosion(position: tower.position.clone(), color: tower.color));
    addCrater(tower.position, 22);
    shakeAt(tower.position, 8);
    AudioService.play('explosion', distance: _distanceToView(tower.position));
    if (tower.ownerId == myId) {
      showNotice(
        tr('${tower.kind.label} ZERSTÖRT', '${tower.kind.label} DESTROYED'),
      );
    } else if ((round?.isEnemy(tower.ownerId) ?? false) &&
        tower.lastHitBy == myId) {
      final bounty = GameConfig.bountyIn(
        GameConfig.creditsPerGun,
        defense.value?.wave ?? 1,
      );
      credits.value += bounty;
      if (!replaying.value) {
        roundStats.kills++;
      }
      world.add(KillMarker(position: tower.position.clone()));
      _showGain(tower.position, bounty);
      showNotice(
        tr(
          'FEINDLICHE ${tower.kind.label} ZERSTÖRT  +$bounty',
          'ENEMY ${tower.kind.label} DESTROYED  +$bounty',
        ),
      );
    }
    if (nearTower.value == tower) {
      nearTower.value = null;
    }
    tower.removeFromParent();
  }

  /// A blast of [ownerId] at [at] wears down the hostile guns and trenches
  /// around it. Only the host keeps their score, every client notes who
  /// hit them.
  void _blastTowers(String ownerId, Vector2 at, double radius, double damage) {
    for (final tower in towers.values.toList()) {
      if (!hurtsTower(ownerId, tower.ownerId)) {
        continue;
      }
      final distance = tower.position.distanceTo(at);
      if (distance <= radius + 26) {
        tower.lastHitBy = ownerId;
        damageTower(tower, damage * (1 - 0.5 * (distance / (radius + 26))));
      }
    }
  }

  /// The closest gun or trench within [range] of [from] that does not
  /// belong to the side of [of]: the defenders' for the enemy, the enemy's
  /// for the defenders, in a duel the other side's.
  Tower? nearestTower(Vector2 from, double range, {String? of}) {
    final activeRound = round;
    final own = activeRound == null || of == null
        ? null
        : activeRound.teamOf(of);
    return _nearestOf(from, range, [
      for (final tower in towers.values)
        // The guns of a base cannot be destroyed: no use shooting at them.
        if (tower.hp > 0 &&
            !tower.isHq &&
            (own == null || activeRound!.teamOf(tower.ownerId) != own))
          tower,
    ]);
  }

  /// Whether the tank of [of] at [at] stands in a trench of its own side.
  /// A trench across the road gives the enemy rolling over it no cover.
  bool inTrench(Vector2 at, {required String of}) => towers.values.any(
    (t) =>
        t.kind == TowerKind.trench &&
        !hurtsTower(of, t.ownerId) &&
        t.position.distanceTo(at) < GameConfig.trenchReach,
  );

  /// One of the local player's guns within reach of [at].
  Tower? _ownTowerAt(Vector2 at) {
    for (final tower in towers.values) {
      if (tower.ownerId == myId &&
          !tower.isHq &&
          tower.position.distanceTo(at) < 48) {
        return tower;
      }
    }
    return null;
  }

  void upgradeTower(Tower tower) {
    if (!tower.kind.upgradable) {
      showNotice(
        tr(
          '${tower.kind.label}: NICHTS AUSZUBAUEN',
          '${tower.kind.label}: NOTHING TO UPGRADE',
        ),
      );
      return;
    }
    if (tower.level >= TowerKind.levelLimit(extended: extended)) {
      showNotice(
        tower.level >= TowerKind.maxLevel
            ? tr('HÖCHSTE STUFE', 'MAXIMUM LEVEL')
            : tr(
                'STUFE ${tower.level + 1} IN DER VERLÄNGERUNG',
                'LEVEL ${tower.level + 1} IN THE EXTENSION',
              ),
      );
      return;
    }
    final cost = tower.kind.upgradeCost(tower.level);
    if (credits.value < cost) {
      showNotice(tr('ZU WENIG MITTEL', 'NOT ENOUGH FUNDS'));
      return;
    }
    credits.value -= cost;
    tower.upgradeTo(tower.level + 1);
    nearTower.value = null;
    nearTower.value = tower;
    net.send(
      NetEvent.tower,
      TowerPayload(
        id: myId,
        index: tower.index,
        x: tower.position.x,
        y: tower.position.y,
        kind: tower.kind.index,
        level: tower.level,
      ).toJson(),
    );
    AudioService.play('go', volume: 0.5);
    showNotice(
      tr(
        '${tower.kind.label} STUFE ${tower.level}',
        '${tower.kind.label} LEVEL ${tower.level}',
      ),
    );
  }

  void _onTower(TowerPayload payload) {
    if (round?.defense ?? false) {
      _addTower(payload);
    }
  }

  void _addTower(TowerPayload payload) {
    final known = towers['${payload.id}#${payload.index}'];
    final hp = payload.hp;
    if (known != null) {
      known.upgradeTo(payload.level.clamp(1, TowerKind.maxLevel));
      if (hp != null && hp < known.hp) {
        known
          ..hp = hp
          ..hit();
        if (hp <= 0) {
          _destroyTower(known);
        }
      }
      return;
    }
    if (hp != null && hp <= 0) {
      return;
    }
    final enemy = round?.isEnemy(payload.id) ?? false;
    final tower = Tower(
      ownerId: payload.id,
      index: payload.index,
      color: enemy ? GameConfig.teamColors[2] : _colorFor(payload.id),
      position: Vector2(payload.x, payload.y),
      kind:
          TowerKind.values[payload.kind.clamp(0, TowerKind.values.length - 1)],
      level: payload.level.clamp(1, TowerKind.maxLevel),
    );
    towers[tower.id] = tower;
    world.add(tower);
    if (enemy) {
      showNotice(
        tr(
          'FEIND GRÄBT ${tower.kind.label} EIN',
          'ENEMY DIGS IN ${tower.kind.label}',
        ),
      );
    }
  }

  /// Host, as a wave rolls in: the enemy digs in guns beside the first
  /// stretch of the road, as many as [GameConfig.enemyGunsIn] the wave,
  /// on the spots of [DefenseMap.enemyGunSpots] that are free. The ones
  /// still standing come up to the wave's level.
  void digInEnemyGuns(int wave) {
    final activeRound = round;
    final map = laneMap(0);
    if (activeRound == null ||
        activeRound.duel ||
        activeRound.botHost != myId ||
        map == null) {
      return;
    }
    final level = GameConfig.enemyGunLevelIn(wave);
    final standing = [
      for (final tower in towers.values)
        if (tower.ownerId == TankGame.enemyGunOwner) tower,
    ];
    for (final tower in standing) {
      if (tower.level < level) {
        tower.upgradeTo(level);
        net.send(
          NetEvent.tower,
          TowerPayload(
            id: tower.ownerId,
            index: tower.index,
            x: tower.position.x,
            y: tower.position.y,
            kind: tower.kind.index,
            level: tower.level,
          ).toJson(),
        );
      }
    }
    var missing = GameConfig.enemyGunsIn(wave) - standing.length;
    for (var i = 0; i < map.enemyGunSpots.length && missing > 0; i++) {
      final at = map.enemyGunSpots[i];
      if (towers.values.any(
        (t) => t.position.distanceTo(at) < GameConfig.towerSpacing,
      )) {
        continue;
      }
      // Cannon and flak by turns, so the players' aircraft get no free
      // run over the enemy either.
      final index = _enemyGunCounter++;
      final payload = TowerPayload(
        id: TankGame.enemyGunOwner,
        index: index,
        x: at.x,
        y: at.y,
        kind: (index.isEven ? TowerKind.cannon : TowerKind.flak).index,
        level: level,
      );
      _addTower(payload);
      net.send(NetEvent.tower, payload.toJson());
      missing--;
    }
  }

  /// A cannon or flak gun this client runs fires where it points: the
  /// local player's, or the enemy's on the player who runs the waves.
  void fireTower(Tower tower) {
    final owner = tower.ownerId;
    final direction = Vector2(sin(tower.turretAngle), -cos(tower.turretAngle));
    final bulletId = '$owner-${_bulletCounter++}';
    final start = tower.position + direction * 44;
    tower.fired(direction);
    _spawnBullet(
      bulletId: bulletId,
      ownerId: owner,
      position: start,
      direction: direction,
      color: tower.color,
      speed: tower.kind.shotSpeed,
      damage: tower.kind.groundDamageAt(tower.level),
      airDamage: tower.kind.airDamageAt(tower.level),
      burst: tower.kind.burst,
      antiAir: tower.kind.antiAir,
    );
    net.send(
      NetEvent.shoot,
      ShootPayload(
        id: owner,
        bulletId: bulletId,
        x: start.x,
        y: start.y,
        dx: direction.x,
        dy: direction.y,
        tower: tower.index,
      ).toJson(),
    );
    AudioService.play(
      'autocannon',
      volume: tower.kind == TowerKind.flak ? 0.3 : 0.5,
      distance: _distanceToView(tower.position),
    );
  }

  /// A mortar or howitzer of the local player lobs a shell onto [at].
  void fireMortarTower(Tower tower, Vector2 at) {
    final from = tower.position.clone();
    tower.fired((at - from).normalized());
    final power = tower.kind.blast * tower.kind.damageFactor(tower.level);
    final grenadeId = '$myId-t${_bulletCounter++}';
    _launchGrenade(
      grenadeId,
      myId,
      from,
      at,
      weapon: SpecialWeapon.shell,
      power: power,
    );
    net.send(
      NetEvent.grenade,
      GrenadePayload(
        id: myId,
        grenadeId: grenadeId,
        x: from.x,
        y: from.y,
        tx: at.x,
        ty: at.y,
        weapon: SpecialWeapon.shell.name,
        power: power,
        tower: tower.index,
      ).toJson(),
    );
    AudioService.play('cannon', distance: _distanceToView(from));
  }

  /// What [tower] should shoot at now. Flak goes for aircraft and drones
  /// first, the cannon for tanks, the rockets for tanks and then aircraft,
  /// the mortar for tanks and soldiers out of
  /// its short range.
  PositionComponent? towerTarget(Tower tower) {
    final at = tower.position;
    final range = tower.range;
    // A gun fights everything not of its own side: the players' the waves
    // and the enemy's guns, the enemy's the players, their comrades, guns
    // and aircraft, in a duel the other player and their troops as well.
    final activeRound = round;
    if (activeRound == null) {
      return null;
    }
    final own = activeRound.teamOf(tower.ownerId);
    TankBase? tanks() => nearestHostile(at, range, own);
    final soldiers = _hostileSoldiers(own);
    Soldier? soldier() => _nearestOf(at, range, soldiers);
    Tower? guns() => nearestTower(at, range, of: tower.ownerId);
    bool hostile(String id) =>
        activeRound.teamOf(id) != 0 && activeRound.teamOf(id) != own;
    PositionComponent? air() => _nearestOf(at, range, [
      for (final plane in aircraft.values)
        if (plane.hp > 0 && hostile(plane.unitId)) plane,
      for (final drone in drones.values)
        if (hostile(drone.ownerId)) drone,
    ]);
    switch (tower.kind) {
      case TowerKind.flak:
        return air() ?? tanks() ?? guns();
      case TowerKind.cannon:
        return tanks() ?? soldier() ?? guns();
      case TowerKind.rockets:
        return tanks() ?? air() ?? soldier() ?? guns();
      case TowerKind.trench:
        return null;
      case TowerKind.mortar || TowerKind.howitzer:
        bool outside(PositionComponent c) =>
            c.position.distanceTo(at) >= tower.kind.minRange;
        final target = _nearestOf(at, range, [
          for (final tank in _allTanks)
            if (tank.team != 0 &&
                tank.team != own &&
                tank.hp > 0 &&
                outside(tank))
              tank,
        ]);
        final gun = guns();
        return target ??
            _nearestOf(at, range, [
              for (final soldier in soldiers)
                if (outside(soldier)) soldier,
            ]) ??
            (gun != null && outside(gun) ? gun : null);
    }
  }

  /// The base held through every wave, or it fell.
  void _endDefense({required bool won}) {
    final activeRound = round;
    if (activeRound == null ||
        phase.value == GamePhase.lobby ||
        phase.value == GamePhase.roundOver) {
      return;
    }
    _respawnTimer = 0;
    respawnSeconds.value = 0;
    roundStats.finish(_secondsIntoRound);
    winnerName.value = won ? tr('Stützpunkt', 'Base') : null;
    if (activeRound.participants.contains(myId)) {
      // A duel is fought by two players on one account: it counts for
      // nobody.
      if (!activeRound.duel) {
        unawaited(
          progress.recordRound(
            name: myName,
            stats: roundStats,
            won: won,
            tankType: GameConfig.typeOf(myColorIndex),
            hpLeft: max(0, myTank?.hp ?? 0),
            soldiers: 0,
            night: false,
            beaten: const [],
            beatenBy: const [],
          ),
        );
      }
      outcome.value = won ? RoundOutcome.won : RoundOutcome.lost;
      AudioService.play(won ? 'win' : 'lose');
      Haptics.roundOver(won: won);
    }
    final state = defense.value;
    final fell = state?.fell ?? -1;
    // In a duel the base that fell goes up, whoever looks at it.
    final base = activeRound.duel && fell >= 0
        ? _defenseField?.baseOf(fell == 2 ? myLane : fell)
        : _defenseField?.headquarters;
    if (base != null) {
      // An extended round is won even when the base falls at last.
      if (!activeRound.duel && won && (state?.hp ?? 1) > 0) {
        final fireworks = Fireworks(centre: () => base.position);
        _extras.add(fireworks);
        world.add(fireworks);
      } else {
        world.add(
          Explosion(
            position: base.position.clone(),
            color: const Color(0xFFFFB300),
          ),
        );
        shakeAt(base.position, 14);
        AudioService.play('explosion');
      }
    }
    _setPhase(GamePhase.roundOver);
    _leaveEndScreenLater(activeRound);
  }
}
