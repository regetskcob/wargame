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
    credits.value = GameConfig.startCredits;
    _towerCounter = 0;
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
            tankColor: GameConfig.colorOf(style),
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
            tankColor: GameConfig.colorOf(style),
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

  /// Whether a shot of [ownerId] wears down a gun of [towerOwner]: the
  /// enemy's in a common round, the other side's and the waves' in a duel.
  bool hurtsTower(String ownerId, String towerOwner) {
    final activeRound = round;
    if (activeRound == null) {
      return false;
    }
    if (!activeRound.duel) {
      return activeRound.isEnemy(ownerId);
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

  /// Host, after the last regular wave: go on with the waves.
  void extendDefense() {
    final state = defense.value;
    if (state == null || round?.botHost != myId || !state.deciding) {
      return;
    }
    publishDefense(
      state.copyWith(
        extended: true,
        nextWaveAt:
            DateTime.now().millisecondsSinceEpoch +
            GameConfig.waveBreakSeconds * 1000,
      ),
    );
  }

  /// Host, between waves once the win is safe: end the round as a win.
  void withdrawDefense() {
    final state = defense.value;
    if (state == null ||
        round?.botHost != myId ||
        state.result != DefenseResult.running ||
        state.nextWaveAt == 0 ||
        !(state.deciding || state.extended)) {
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
    if (before != null && state.extended && !before.extended) {
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
        state.deciding
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
    final reason = locked != null
        ? '${build.label} $locked'
        : credits.value < build.cost
        ? tr('Zu wenig Mittel', 'Not enough funds')
        : mine >= limit
        ? build.isGun
              ? tr('Höchstens $limit Geschütze', 'At most $limit turrets')
              : tr('Höchstens $limit Gräben', 'At most $limit trenches')
        : map.whyNotBuild(tank.position, towers.values.map((t) => t.position));
    if (reason != null) {
      showNotice(reason.toUpperCase());
      return;
    }
    credits.value -= build.cost;
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
    showNotice('${next.label} ${next.cost}');
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
    }
    if (nearTower.value == tower) {
      nearTower.value = null;
    }
    tower.removeFromParent();
  }

  /// Host: a blast of the enemy at [at] wears down the guns and trenches
  /// around it.
  void _blastTowers(String ownerId, Vector2 at, double radius, double damage) {
    for (final tower in towers.values.toList()) {
      if (!hurtsTower(ownerId, tower.ownerId)) {
        continue;
      }
      final distance = tower.position.distanceTo(at);
      if (distance <= radius + 26) {
        damageTower(tower, damage * (1 - 0.5 * (distance / (radius + 26))));
      }
    }
  }

  /// The closest gun or trench of the defenders within [range] of [from],
  /// for the enemy to shoot at when no tank is near.
  /// In a duel only the guns of the side other than that of [of], the
  /// guns of a base included.
  Tower? nearestTower(Vector2 from, double range, {String? of}) {
    final activeRound = round;
    final duel = activeRound != null && activeRound.duel && of != null;
    final own = duel ? activeRound.teamOf(of) : 0;
    return _nearestOf(from, range, [
      for (final tower in towers.values)
        // The guns of a base cannot be destroyed: no use shooting at them.
        if (tower.hp > 0 &&
            !tower.isHq &&
            (!duel || activeRound.teamOf(tower.ownerId) != own))
          tower,
    ]);
  }

  /// Whether a tank at [at] stands in a trench, any player's.
  bool inTrench(Vector2 at) => towers.values.any(
    (t) =>
        t.kind == TowerKind.trench &&
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
    final tower = Tower(
      ownerId: payload.id,
      index: payload.index,
      color: _colorFor(payload.id),
      position: Vector2(payload.x, payload.y),
      kind:
          TowerKind.values[payload.kind.clamp(0, TowerKind.values.length - 1)],
      level: payload.level.clamp(1, TowerKind.maxLevel),
    );
    towers[tower.id] = tower;
    world.add(tower);
  }

  /// A cannon or flak gun of the local player fires where it points.
  void fireTower(Tower tower) {
    final direction = Vector2(sin(tower.turretAngle), -cos(tower.turretAngle));
    final bulletId = '$myId-${_bulletCounter++}';
    final start = tower.position + direction * 44;
    tower.fired(direction);
    _spawnBullet(
      bulletId: bulletId,
      ownerId: myId,
      position: start,
      direction: direction,
      color: tower.color,
      speed: tower.kind.shotSpeed,
      damage: tower.kind.damage * tower.kind.damageFactor(tower.level),
      antiAir: tower.kind.antiAir,
    );
    net.send(
      NetEvent.shoot,
      ShootPayload(
        id: myId,
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
    // In a duel a gun fights everything not of its own side: the waves, the
    // other player and their troops and guns.
    final activeRound = round;
    final duel = activeRound?.duel ?? false;
    final own = duel ? activeRound!.teamOf(tower.ownerId) : 1;
    TankBase? tanks() =>
        duel ? nearestHostile(at, range, own) : nearestEnemy(at, range);
    final soldiers = duel ? _hostileSoldiers(own) : _enemySoldiers;
    Soldier? soldier() => _nearestOf(at, range, soldiers);
    Tower? guns() => duel ? nearestTower(at, range, of: tower.ownerId) : null;
    bool hostile(String id) => duel
        ? activeRound!.teamOf(id) != 0 && activeRound.teamOf(id) != own
        : activeRound?.isEnemy(id) ?? false;
    PositionComponent? air() => _nearestOf(at, range, [
      for (final plane in aircraft.values)
        if (plane.hp > 0 && (duel ? hostile(plane.unitId) : !plane.friendly))
          plane,
      for (final drone in drones.values)
        if (hostile(drone.ownerId)) drone,
    ]);
    switch (tower.kind) {
      case TowerKind.flak:
        return air() ?? tanks();
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
            if ((duel ? tank.team != 0 && tank.team != own : tank.team == 2) &&
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
    Future<void>.delayed(
      const Duration(seconds: GameConfig.roundOverSeconds),
      () {
        if (round == activeRound && phase.value == GamePhase.roundOver) {
          backToLobby();
        }
      },
    );
  }
}
