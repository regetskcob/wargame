part of '../tank_game.dart';

/// A round from start to end: the round start and its world, spawning, tank state from the others, deaths and kills, respawn and resupply, the end of the round, spectating and clearing up.
extension TankGameRound on TankGame {
  void _setGround(MapTheme theme, {bool plain = false}) {
    _ground?.removeFromParent();
    _ground = Ground(theme, plain: plain);
    world.add(_ground!);
    mapName.value = theme.name;
  }

  /// Starts a round. A duel on the Apple TV hands both of its games the
  /// same [seed] and [startedAt], so both play the same map and waves at
  /// the same time.
  void startRound({int? seed, int? startedAt}) {
    if (phase.value != GamePhase.lobby || !canStart) {
      return;
    }
    // Single player with a second player on the same Apple TV: both
    // together against the CPU tanks, in a round the other one hears of.
    final together = mode.value == GameMode.solo && localGuest;
    final solo = mode.value == GameMode.solo && !together;
    final defending = mode.value == GameMode.defense;
    final flag = mode.value == GameMode.flag;
    // Players still looking at the last end screen come along as well.
    final ids = <String>{
      myId,
      if (!solo)
        for (final member in roster.value)
          if (member.phase == GamePhase.lobby.name ||
              member.phase == GamePhase.roundOver.name)
            member.id,
    }.toList();
    final random = Random();
    final botCount = botsFor(
      solo: solo || together,
      humans: ids.length,
      // A phone in the room leaves no Realtime room for CPU tanks.
      // Capturing the flag always fills the sides up with CPU tanks.
      fill: (fillWithBots.value || flag) && !defending && !roomHasPhone,
      teams: teamMode.value || flag,
      fillTo: flag ? GameConfig.flagFillTo : GameConfig.fillTo,
      random: random,
    );
    final bots = <String, int>{
      for (var i = 1; i <= botCount; i++)
        'cpu-$i': GameConfig.randomStyle(random),
    };
    ids
      ..addAll(bots.keys)
      ..sort();
    // A duel takes exactly two players, the host on the left.
    final humans = [
      for (final id in ids)
        if (!bots.containsKey(id)) id,
    ];
    final lanes = defending && duelNext.value && humans.length == 2
        ? [myId, humans.firstWhere((id) => id != myId)]
        : const <String>[];
    final payload = RoundStartPayload(
      seed:
          seed ??
          switch (mapChoice.value) {
            final map? => MapTheme.seedFor(Random().nextInt(1 << 30), map),
            null => Random().nextInt(1 << 30),
          },
      startedAt:
          startedAt ??
          DateTime.now().millisecondsSinceEpoch +
              GameConfig.countdownSeconds * 1000,
      participants: ids,
      teams: defending
          ? const {}
          : together
          ? {for (final id in ids) id: bots.containsKey(id) ? 2 : 1}
          : _assignTeams(ids, force: flag),
      bots: bots,
      botHost: bots.isEmpty && !defending && !flag ? null : myId,
      defense: defending,
      flag: flag,
      lanes: lanes,
      // Also without CPU tanks: the level sets fuel, ammo and terrain.
      botLevel: botLevel.value.index,
    );
    if (!solo) {
      net.send(NetEvent.roundStart, payload.toJson());
    }
    _applyRoundStart(payload);
  }

  void spectateLiveMatch() {
    if (phase.value != GamePhase.lobby) {
      return;
    }
    final live = liveMatch;
    if (live == null) {
      return;
    }
    final participants = [
      for (final member in roster.value)
        if (member.id != myId &&
            member.inMatch &&
            TankGame._liveMatchPhases.contains(member.phase))
          member.id,
    ]..sort();
    if (participants.isEmpty) {
      return;
    }
    final payload = RoundStartPayload(
      seed: live.seed!,
      startedAt: live.startedAt!,
      participants: participants,
      teams: {
        if (!live.defense)
          for (final member in roster.value)
            if (member.inMatch && member.team > 0) member.id: member.team,
      },
      defense: live.defense,
      flag: live.flag,
      botHost: live.botHost,
    );
    _applyRoundStart(payload);
  }

  void _onRoundStart(RoundStartPayload payload) {
    // A real round beats watching an old one.
    if (replaying.value) {
      stopReplay();
    }
    final activeRound = round;
    // Players still looking at the results join a rematch straight away.
    if (phase.value == GamePhase.lobby ||
        (phase.value == GamePhase.roundOver &&
            payload.participants.contains(myId))) {
      _applyRoundStart(payload);
      return;
    }
    final beforeStart =
        phase.value == GamePhase.countdown ||
        phase.value == GamePhase.spectating;
    if (beforeStart && activeRound != null && _outranks(payload, activeRound)) {
      _applyRoundStart(payload);
    }
  }

  bool _outranks(RoundStartPayload payload, RoundState current) {
    if (payload.startedAt != current.startedAt) {
      return payload.startedAt < current.startedAt;
    }
    return payload.seed < current.seed;
  }

  /// Builds the world of a round. With [replay] every tank is driven by the
  /// recorded messages and the local player only watches.
  void _applyRoundStart(RoundStartPayload payload, {bool replay = false}) {
    _clearWorld();
    _lastActivity = DateTime.now();
    final activeRound = RoundState(
      seed: payload.seed,
      startedAt: payload.startedAt,
      participants: List.of(payload.participants)..sort(),
      teams: payload.teams,
      bots: payload.bots,
      botHost: payload.botHost,
      botLevel: BotLevel.of(payload.botLevel),
      defense: payload.defense,
      lanes: payload.defense ? payload.lanes : const [],
      flag: payload.flag && !payload.defense,
    );
    myTeam = activeRound.teamOf(myId);
    guard.reset();
    killFeed.value = const [];
    if (!replay) {
      progress.clearRound();
      _uids
        ..clear()
        ..addAll({
          for (final member in roster.value)
            if (member.uid case final uid?
                when TankGame._accountIdPattern.hasMatch(uid) &&
                    payload.participants.contains(member.id))
              member.id: uid,
        });
      roundStats = RoundStats();
    }
    round = activeRound;
    if (activeRound.defense) {
      _setUpDefense(activeRound);
      return;
    }
    _coverField = CoverField(seed: payload.seed);
    _setGround(_coverField!.theme);
    conditions = Conditions.forSeed(payload.seed);
    conditionsLabel.value = conditions!.label;
    _weather = WeatherLayer(conditions!);
    // Capturing the flag needs the whole field, so no zone closes in.
    _stormZone = activeRound.flag
        ? null
        : StormZone(startedAt: payload.startedAt);
    _powerUpSlots = PowerUpSlot.schedule(payload.seed, activeRound.botLevel);
    world.add(_coverField!);
    _setUpSupply(activeRound);
    _raiseTerrain(
      activeRound,
      _coverField!.theme,
      area: Rect.fromCircle(
        center: Offset.zero,
        radius: GameConfig.worldRadius,
      ),
      keepClear: activeRound.flag
          ? [FlagMatch.baseOf(1), FlagMatch.baseOf(2)]
          : const [],
    );
    soldierField = SoldierField(
      seed: payload.seed,
      startedAt: payload.startedAt,
      onWave: () =>
          showNotice(tr('FALLSCHIRMJÄGER IM ANFLUG', 'PARATROOPERS INBOUND')),
      armedSides: activeRound.teamMode,
    );
    _extras.add(soldierField!);
    world.add(soldierField!);
    soldiersRunOver.value = 0;
    if (_stormZone case final zone?) {
      world.add(zone);
    }
    mudField = MudField(seed: payload.seed, theme: _coverField!.theme);
    world.add(mudField!);
    for (var i = 0; i < activeRound.participants.length; i++) {
      final id = activeRound.participants[i];
      final slotAngle = 2 * pi * i / activeRound.participants.length;
      final ring = Vector2(cos(slotAngle), sin(slotAngle))
        ..scale(GameConfig.spawnRadius);
      final (spawn, facing) = activeRound.flag
          ? _flagSpawn(activeRound, id)
          : (ring, atan2(-ring.x, ring.y));
      if (id == myId && !replay) {
        _spawnLocalTank(spawn, facing);
      } else if (!replay &&
          activeRound.isBot(id) &&
          activeRound.botHost == myId) {
        _spawnBot(activeRound, id, spawn, facing);
      } else {
        _addRemoteTank(id, spawn, facing);
      }
    }
    if (activeRound.flag) {
      _setUpFlag();
    }
    _enterRound(activeRound, payload: payload, replay: replay);
  }

  /// A CPU tank this host drives, with the brain that steers it.
  void _spawnBot(RoundState activeRound, String id, Vector2 at, double facing) {
    final controls = TouchInput();
    final tank = PlayerTank(
      playerId: id,
      playerName: _nameFor(id),
      tankColor: _colorFor(id),
      tankType: GameConfig.typeOf(_styleFor(id)),
      position: at,
      angle: facing,
      controls: controls,
    );
    tank
      ..team = activeRound.teamOf(id)
      ..usesFuel = usesFuel
      ..endlessAmmo = endlessAmmo;
    botTanks[id] = tank;
    world.add(tank);
    final brain = BotBrain(
      tank: tank,
      controls: controls,
      level: activeRound.botLevel,
      objective: activeRound.flag ? flagGoal : null,
    );
    _extras.add(brain);
    world.add(brain);
  }

  /// Last step of a round start. [payload] is given for rounds that are
  /// recorded for a replay, [replay] while one is shown.
  void _enterRound(
    RoundState activeRound, {
    RoundStartPayload? payload,
    bool replay = false,
  }) {
    hpNotifier.value = myMaxHp;
    inventory.clear();
    upgrades.value = const {};
    ammoNotifier.value = myMagazine;
    specialNotifier.value = null;
    aliveCount.value = activeRound.alive.length;
    winnerName.value = null;
    if (replay) {
      _setPhase(GamePhase.spectating);
      final targets = [...remoteTanks.keys];
      _spectateByIndex(max(0, targets.indexOf(myId)));
      return;
    }
    if (payload != null) {
      _recorder.start(
        payload,
        names: {for (final id in activeRound.participants) id: _nameFor(id)},
        styles: {for (final id in activeRound.participants) id: _styleFor(id)},
      );
    }
    if (activeRound.participants.contains(myId)) {
      _setPhase(GamePhase.countdown);
    } else {
      _setPhase(GamePhase.spectating);
      _spectateByIndex(0);
    }
    unawaited(pushPresence());
  }

  PlayerTank _spawnLocalTank(Vector2 at, double facing) {
    final tank = PlayerTank(
      playerId: myId,
      playerName: myName,
      tankColor: _colorFor(myId),
      tankType: GameConfig.typeOf(myColorIndex),
      position: at,
      angle: facing,
    );
    myTank = tank;
    tank
      ..team = round?.teamOf(myId) ?? 0
      ..usesFuel = usesFuel
      ..endlessAmmo = endlessAmmo;
    fuelNotifier.value = 1;
    _applyUpgrades(tank);
    world.add(tank);
    if (!overview.value) {
      camera.follow(tank, snap: true);
    }
    return tank;
  }

  RemoteTank _addRemoteTank(String id, Vector2 at, double facing) {
    final style = _styleFor(id);
    final tank = RemoteTank(
      playerId: id,
      playerName: _nameFor(id),
      tankColor: _colorFor(id),
      tankType: GameConfig.typeOf(style),
      position: at,
      angle: facing,
    );
    tank.team = round?.teamOf(id) ?? 0;
    remoteTanks[id] = tank;
    world.add(tank);
    return tank;
  }

  /// Lets the weather turn and day and night take turns when the seed and
  /// the round clock say so, and fades the old sky out while the new one
  /// comes in.
  void _turnWeather(double dt) {
    final current = _weather;
    if (current != null && current.opacity < 1) {
      current.opacity = min(1, current.opacity + dt / TankGame._weatherFade);
    }
    final passing = _passingWeather;
    if (passing != null) {
      passing
        ..update(dt)
        ..opacity -= dt / TankGame._weatherFade;
      if (passing.opacity <= 0) {
        _passingWeather = null;
      }
    }
    _weatherCheck -= dt;
    final activeRound = round;
    final now = conditions;
    if (_weatherCheck > 0 || activeRound == null || now == null) {
      return;
    }
    _weatherCheck = 1;
    final next = Conditions.at(activeRound.seed, _secondsIntoRound, now.theme);
    if (next.sky == now.sky && next.night == now.night) {
      return;
    }
    conditions = next;
    conditionsLabel.value = next.label;
    _passingWeather = current;
    _weather = WeatherLayer(next)..opacity = 0;
    if (phase.value == GamePhase.playing) {
      showNotice(switch ((next.sky == now.sky, next.night)) {
        (true, true) => tr('DIE NACHT BRICHT HEREIN', 'NIGHT IS FALLING'),
        (true, false) => tr('DER TAG BRICHT AN', 'DAY IS BREAKING'),
        _ => tr(
          'WETTERUMSCHWUNG: ${next.label.toUpperCase()}',
          'WEATHER CHANGE: ${next.label.toUpperCase()}',
        ),
      });
    }
  }

  /// Hills and hollows for the level of [activeRound], none on easy.
  void _raiseTerrain(
    RoundState activeRound,
    MapTheme theme, {
    required Rect area,
    Iterable<Vector2> keepClear = const [],
  }) {
    terrain = Terrain.forSeed(
      activeRound.seed,
      activeRound.botLevel,
      area: area,
      keepClear: keepClear,
    );
    if (terrain.isFlat) {
      return;
    }
    _terrainLayer = TerrainLayer(
      terrain: terrain,
      theme: theme,
      seed: activeRound.seed,
    );
    world.add(_terrainLayer!);
  }

  void _updateRespawn(double dt) {
    if (_respawnTimer <= 0) {
      return;
    }
    _respawnTimer -= dt;
    respawnSeconds.value = max(0, _respawnTimer.ceil());
    if (_respawnTimer > 0) {
      return;
    }
    final activeRound = round;
    if (activeRound == null || phase.value != GamePhase.playing) {
      return;
    }
    if (activeRound.flag) {
      // Back at the own base.
      final (at, facing) = _flagSpawn(activeRound, myId);
      _spawnLocalTank(at, facing);
    } else {
      // In a duel back at the base of the own side.
      final map = myLaneMap;
      if (map == null) {
        return;
      }
      final at = activeRound.duel
          ? map.spawnFor(0, 1)
          : map.spawnFor(
              activeRound.participants.indexOf(myId),
              activeRound.participants.length,
            );
      _spawnLocalTank(
        at,
        TankGame._headingFrom(at, map.road[map.road.length - 2]),
      );
    }
    activeRound.alive.add(myId);
    aliveCount.value = activeRound.alive.length;
    hpNotifier.value = myMaxHp;
    ammoNotifier.value = myMagazine;
    specialNotifier.value = null;
  }

  /// Defense round: the base is the ammo dump. A tank next to it gets its
  /// magazine refilled bit by bit, since no gems lie on this map.
  void _resupply(double dt) {
    final tank = myTank;
    // In a duel only the own base hands out ammunition.
    final map = myLaneMap;
    if (tank == null || map == null || phase.value != GamePhase.playing) {
      nearTower.value = null;
      return;
    }
    nearTower.value = _ownTowerAt(tank.position);
    final near =
        tank.position.distanceTo(map.base) <
        DefenseMap.baseRadius + GameConfig.resupplyReach;
    if (near && tank.usesFuel && tank.fuel < 1) {
      tank.setFuel(tank.fuel + dt / GameConfig.resupplySeconds);
    }
    if (!near || tank.ammo >= tank.magazine) {
      _resupplied = 0;
      return;
    }
    _resupplied += dt * tank.magazine / GameConfig.resupplySeconds;
    if (_resupplied >= 1) {
      final rounds = _resupplied.floor();
      _resupplied -= rounds;
      tank.setAmmo(tank.ammo + rounds);
    }
  }

  /// The CPU tanks of a round, all in one message. Only the host that
  /// drives them sends it.
  void _onTankStates(TankStatesPayload payload) {
    if (payload.id != round?.botHost) {
      return;
    }
    payload.states.forEach(_onTankState);
  }

  void _onTankState(TankStatePayload raw) {
    final activeRound = round;
    if (activeRound == null) {
      return;
    }
    final tank = remoteTanks[raw.id];
    if (tank == null) {
      // In a defense round enemies roll in during the round and players come
      // back after they were destroyed.
      final joins =
          (activeRound.defense &&
              !activeRound.destroyedEnemies.contains(raw.id) &&
              (activeRound.isEnemy(raw.id) ||
                  activeRound.isAlly(raw.id) ||
                  activeRound.participants.contains(raw.id))) ||
          _respawnedInFlag(activeRound, raw.id);
      if (joins) {
        activeRound.alive.add(raw.id);
        aliveCount.value = activeRound.alive.length;
      }
      if (!activeRound.alive.contains(raw.id)) {
        return;
      }
      // A tank that comes back starts somewhere else: judge it afresh.
      guard.forget(raw.id);
    }
    final checked = guard.checkState(raw.id, x: raw.x, y: raw.y, hp: raw.hp);
    final payload = TankStatePayload(
      id: raw.id,
      x: checked.x,
      y: checked.y,
      vx: raw.vx,
      vy: raw.vy,
      rotation: raw.rotation,
      hp: checked.hp,
      turret: raw.turret,
      shielded: raw.shielded,
    );
    if (tank != null) {
      tank.applyState(payload);
      return;
    }
    _addRemoteTank(
      payload.id,
      Vector2(payload.x, payload.y),
      payload.rotation,
    ).applyState(payload);
  }

  /// A tank of a capture the flag round is back from its base. A state
  /// sent just before it went down does not count.
  bool _respawnedInFlag(RoundState activeRound, String id) {
    if (!activeRound.flag ||
        !activeRound.participants.contains(id) ||
        activeRound.left.contains(id)) {
      return false;
    }
    final down = activeRound.downAt[id];
    return down == null ||
        DateTime.now().millisecondsSinceEpoch - down >
            GameConfig.respawnSeconds * 500;
  }

  /// Top speed factor of every tank in this round, see
  /// [GameConfig.watchSoloSpeed].
  double get tankSpeedScale =>
      onWatch && mode.value == GameMode.solo ? GameConfig.watchSoloSpeed : 1.0;

  double get _secondsIntoRound {
    final started = round?.startedAt;
    return started == null
        ? 0
        : (DateTime.now().millisecondsSinceEpoch - started) / 1000;
  }

  void _onDeath(DeathPayload payload) {
    if (round?.alive.contains(payload.id) != true ||
        !guard.allowDeath(payload.id)) {
      return;
    }
    _recordKill(payload.id, payload.killerId);
    _handleRemoteDeath(payload.id, explode: true);
  }

  void onLocalDeath(String? killerId) {
    final tank = myTank;
    if (tank == null) {
      return;
    }
    net.send(
      NetEvent.death,
      DeathPayload(id: myId, killerId: killerId).toJson(),
    );
    _recordKill(myId, killerId);
    if (round?.respawns ?? false) {
      // Defenders and flag hunters come back after a short while, the
      // round goes on.
      round?.alive.remove(myId);
      world.add(
        Explosion(position: tank.position.clone(), color: tank.tankColor),
      );
      shake(12);
      if (!(round?.flag ?? false)) {
        _addWreck(tank);
      }
      AudioService.play('explosion');
      Haptics.destroyed();
      tank.removeFromParent();
      myTank = null;
      camera.stop();
      aliveCount.value = round?.alive.length ?? 0;
      _respawnTimer = GameConfig.respawnSeconds;
      respawnSeconds.value = _respawnTimer.ceil();
      return;
    }
    roundStats.finish(_secondsIntoRound);
    round?.markDead(myId);
    world.add(
      Explosion(position: tank.position.clone(), color: tank.tankColor),
    );
    shake(12);
    _addWreck(tank);
    AudioService.play('explosion');
    Haptics.destroyed();
    outcome.value = RoundOutcome.lost;
    tank.removeFromParent();
    myTank = null;
    aliveCount.value = round?.alive.length ?? 0;
    _setPhase(GamePhase.spectating);
    _spectateByIndex(0);
    unawaited(pushPresence());
    _checkRoundEnd();
  }

  void _addWreck(TankBase tank) {
    final wreck = Wreck(
      position: tank.position.clone(),
      angle: tank.angle,
      tankType: tank.tankType,
      hullSize: tank.size.x,
    );
    _extras.add(wreck);
    world.add(wreck);
  }

  void _recordKill(String victimId, String? killerId) {
    final activeRound = round;
    if (activeRound == null) {
      return;
    }
    if (killerId == null && activeRound.isEnemy(victimId)) {
      // An enemy that blew itself up at the base, the base bar shows it.
      return;
    }
    if (killerId == myId && victimId != myId) {
      if (!replaying.value) {
        roundStats.kills++;
      }
      final PositionComponent? victim =
          remoteTanks[victimId] ?? botTanks[victimId] ?? aircraft[victimId];
      if (victim != null) {
        world.add(KillMarker(position: victim.position.clone()));
        shake(4);
      }
      // In a duel the other player's tank pays as well.
      if (activeRound.isEnemy(victimId) ||
          (activeRound.duel && activeRound.lanes.contains(victimId))) {
        credits.value += GameConfig.bountyIn(
          aircraft.containsKey(victimId)
              ? GameConfig.creditsPerAircraft
              : GameConfig.creditsPerKill,
          defense.value?.wave ?? 1,
        );
      }
    }
    final entry = KillEntry(
      victim: _nameOf(victimId),
      victimTeam: activeRound.teamOf(victimId),
      killer: killerId == null ? null : _nameOf(killerId),
      killerTeam: killerId == null ? 0 : activeRound.teamOf(killerId),
      byMe: killerId == myId,
      meDied: victimId == myId,
      at: DateTime.now(),
    );
    killFeed.value = [
      ...killFeed.value,
      entry,
    ].reversed.take(6).toList().reversed.toList();
  }

  /// Broadcast is fire and forget, so a death message can get lost, and a
  /// player whose window froze never sends one. Every tank sends its state at
  /// least once a second, so one that has been silent for long is gone.
  /// Without this the round would wait forever for an enemy that is not there.
  void _dropSilentTanks() {
    final current = phase.value;
    if (current != GamePhase.playing && current != GamePhase.spectating) {
      return;
    }
    final now = DateTime.now();
    for (final entry in remoteTanks.entries.toList()) {
      if (now.difference(entry.value.lastSeen) > GameConfig.silentTankTimeout) {
        _handleRemoteDeath(entry.key, explode: false);
      }
    }
  }

  /// A bot of this client was destroyed.
  void onBotDeath(PlayerTank bot, String? killerId) {
    final activeRound = round;
    if (activeRound == null || !botTanks.containsKey(bot.playerId)) {
      return;
    }
    net.send(
      NetEvent.death,
      DeathPayload(id: bot.playerId, killerId: killerId).toJson(),
    );
    _recordKill(bot.playerId, killerId);
    activeRound.markDead(bot.playerId);
    if (activeRound.flag) {
      _botRespawns[bot.playerId] = GameConfig.respawnSeconds;
    } else {
      activeRound.destroyedEnemies.add(bot.playerId);
    }
    aliveCount.value = activeRound.alive.length;
    world.add(Explosion(position: bot.position.clone(), color: bot.tankColor));
    shakeAt(bot.position, 8);
    // Rounds where tanks come back would leave far too many wrecks, only
    // the explosion stays.
    if (!activeRound.respawns) {
      _addWreck(bot);
    }
    AudioService.play('explosion', distance: _distanceToView(bot.position));
    botTanks.remove(bot.playerId);
    bot.removeFromParent();
    _refreshSpectateTarget();
    _checkRoundEnd();
  }

  void _onPeerLeft(String id) {
    if (replaying.value) {
      return;
    }
    final tank = remoteTanks.remove(id);
    tank?.removeFromParent();
    final activeRound = round;
    if (activeRound != null && activeRound.defense) {
      for (final tower in towers.values.where((t) => t.ownerId == id)) {
        tower.removeFromParent();
      }
      towers.removeWhere((_, tower) => tower.ownerId == id);
      if (activeRound.botHost == id) {
        // Nobody runs the waves any more, the base is lost.
        _endDefense(won: false);
        return;
      }
    }
    if (activeRound != null && activeRound.botHost == id) {
      // Nobody simulates the bots any more.
      activeRound.left.addAll(activeRound.bots.keys);
      for (final botId in activeRound.bots.keys) {
        if (activeRound.alive.contains(botId)) {
          _handleRemoteDeath(botId, explode: false);
        }
      }
    }
    if (activeRound != null &&
        activeRound.flag &&
        activeRound.participants.contains(id)) {
      activeRound.left.add(id);
      _handOverFlags(activeRound);
    }
    if (activeRound != null && activeRound.markDead(id)) {
      aliveCount.value = activeRound.alive.length;
      _refreshSpectateTarget();
      _checkRoundEnd();
    }
  }

  void _handleRemoteDeath(String id, {required bool explode}) {
    final activeRound = round;
    if (activeRound == null) {
      return;
    }
    activeRound.markDead(id);
    if (activeRound.isEnemy(id) || activeRound.isAlly(id)) {
      activeRound.destroyedEnemies.add(id);
    }
    aliveCount.value = activeRound.alive.length;
    final tank = remoteTanks.remove(id);
    if (tank != null) {
      if (explode) {
        world.add(
          Explosion(position: tank.position.clone(), color: tank.tankColor),
        );
        shakeAt(tank.position, 8);
        if (!activeRound.isEnemy(id) &&
            !activeRound.isAlly(id) &&
            !activeRound.flag) {
          _addWreck(tank);
        }
        AudioService.play(
          'explosion',
          distance: _distanceToView(tank.position),
        );
      }
      tank.removeFromParent();
    }
    _refreshSpectateTarget();
    _checkRoundEnd();
  }

  void _checkRoundEnd() {
    final activeRound = round;
    if (activeRound == null) {
      return;
    }
    if (phase.value == GamePhase.lobby || phase.value == GamePhase.roundOver) {
      return;
    }
    if (activeRound.defense || activeRound.flag) {
      // Only the base decides a defense round, see [_applyDefense], and
      // only the flags a capture the flag round, see [_checkFlagEnd].
      return;
    }
    if (activeRound.teamMode) {
      final teams = activeRound.alive.map(activeRound.teamOf).toSet();
      if (teams.length > 1) {
        return;
      }
      final team = teams.isEmpty ? null : teams.first;
      _endRound(
        team == null
            ? null
            : activeRound.alive.firstWhere(
                (id) => activeRound.teamOf(id) == team,
              ),
        winnerTeam: team,
      );
      return;
    }
    if (activeRound.participants.length < 2) {
      if (activeRound.alive.isNotEmpty) {
        return;
      }
    } else if (activeRound.alive.length > 1) {
      return;
    }
    final winnerId = activeRound.alive.length == 1
        ? activeRound.alive.first
        : null;
    _endRound(winnerId);
  }

  void _endRound(String? winnerId, {int? winnerTeam}) {
    final activeRound = round;
    if (activeRound == null) {
      return;
    }
    activeRound
      ..winnerId = winnerId
      ..winnerTeam = winnerTeam;
    if (replaying.value) {
      // The replay runs to its last message and ends by itself.
      return;
    }
    roundStats.finish(_secondsIntoRound);
    final teamWin = winnerTeam != null;
    final myTeamWon = teamWin && myTeam == winnerTeam;
    if (teamWin) {
      winnerName.value = 'Team ${GameConfig.teamNames[winnerTeam]}';
    } else if (winnerId == null) {
      winnerName.value = null;
    } else if (winnerId == myId) {
      winnerName.value = myName;
    } else {
      winnerName.value =
          remoteTanks[winnerId]?.playerName ??
          _rosterMember(winnerId)?.name ??
          (activeRound.isBot(winnerId)
              ? activeRound.botName(winnerId)
              : tr('Panzer', 'Tank'));
    }
    final won = teamWin ? myTeamWon : winnerId != null && winnerId == myId;
    if (activeRound.participants.contains(myId)) {
      final placements = activeRound.placementsOf(myId);
      final cpu = activeRound.cpuPlacementsOf(myId);
      List<String> accounts(List<String> ids) => [
        for (final id in ids) ?_uids[id],
      ];
      unawaited(
        progress.recordRound(
          name: myName,
          stats: roundStats,
          won: won,
          tankType: GameConfig.typeOf(myColorIndex),
          hpLeft: max(0, myTank?.hp ?? 0),
          soldiers: soldiersRunOver.value,
          night: conditions?.night ?? false,
          beaten: accounts(placements.beaten),
          beatenBy: accounts(placements.beatenBy),
          cpuBeaten: cpu.beaten,
          cpuBeatenBy: cpu.beatenBy,
          cpuRating: activeRound.botLevel.rating,
        ),
      );
    }
    if (won) {
      outcome.value = RoundOutcome.won;
      AudioService.play('win');
      Haptics.roundOver(won: true);
    } else if (activeRound.participants.contains(myId)) {
      outcome.value = RoundOutcome.lost;
      AudioService.play('lose');
      Haptics.roundOver(won: false);
    }
    if (winnerId != null) {
      final winner = winnerId == myId
          ? myTank
          : remoteTanks[winnerId] ?? botTanks[winnerId];
      if (winner != null) {
        final fireworks = Fireworks(centre: () => winner.position);
        _extras.add(fireworks);
        world.add(fireworks);
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

  void backToLobby() {
    overview.value = false;
    if (phase.value != GamePhase.roundOver) {
      return;
    }
    _clearWorld();
    round = null;
    myTeam = 0;
    _lastActivity = DateTime.now();
    _setPhase(GamePhase.lobby);
    unawaited(pushPresence());
  }

  /// Whether the player is in a round that leaving would cut short.
  bool get inRound => switch (phase.value) {
    // The countdown shows no question and is over in a moment.
    GamePhase.playing ||
    GamePhase.spectating => round != null && !replaying.value,
    _ => false,
  };

  /// Escape and, while the leave question is open, Enter. True when the key
  /// was used up.
  bool handleEscape(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.escape) {
      if (replaying.value) {
        stopReplay();
        return true;
      }
      if (phase.value == GamePhase.roundOver) {
        backToLobby();
        return true;
      }
      if (inRound) {
        // A second Escape takes the question back.
        leaveAsked.value = !leaveAsked.value;
        return true;
      }
      return false;
    }
    if (leaveAsked.value &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      leaveRound();
      return true;
    }
    return false;
  }

  /// Leaves the running round. Alone with CPU tanks the player is straight
  /// back in the waiting room. With other people in the round the player
  /// leaves the room as well: the others then see the tank go like any
  /// pilot who closes the tab, instead of waiting for one that no longer
  /// reports.
  void leaveRound() {
    leaveAsked.value = false;
    final activeRound = round;
    if (activeRound == null || !inRound) {
      return;
    }
    final others = activeRound.participants.any(
      (id) => id != myId && !activeRound.bots.containsKey(id),
    );
    if (others) {
      _enterClosed(tr('Du hast die Runde verlassen.', 'You left the round.'));
      fireAndForget(net.dispose(), 'Leaving the room');
      return;
    }
    overview.value = false;
    _clearWorld();
    round = null;
    myTeam = 0;
    _lastActivity = DateTime.now();
    _setPhase(GamePhase.lobby);
    unawaited(pushPresence());
  }

  /// Host only: straight from the results into the next round, with the same
  /// settings and everybody who is still in the room.
  void rematch() {
    if (phase.value != GamePhase.roundOver || !canStart) {
      return;
    }
    backToLobby();
    startRound();
  }

  /// One based position of the watched tank, for the button label.
  int get spectateNumber => _spectateIndex + 1;

  void spectateNext() {
    _spectateByIndex(_spectateIndex + 1);
  }

  void _refreshSpectateTarget() {
    if (phase.value == GamePhase.spectating) {
      _spectateByIndex(_spectateIndex);
    }
  }

  void _spectateByIndex(int index) {
    final targets = [...remoteTanks.values, ...botTanks.values];
    if (targets.isEmpty) {
      spectatingName.value = null;
      camera.stop();
      return;
    }
    _spectateIndex = index % targets.length;
    final target = targets[_spectateIndex];
    spectatingName.value = target.playerName;
    if (!overview.value) {
      camera.follow(target, snap: false);
    }
  }

  void _clearWorld() {
    _botStates.clear();
    final recorded = _recorder.finish();
    if (recorded != null) {
      lastReplay.value = recorded;
    }
    _setGround(MapTheme.forest);
    conditions = null;
    conditionsLabel.value = null;
    _weather = null;
    _passingWeather = null;
    _coverField?.removeFromParent();
    _coverField = null;
    _clearSupply();
    mudField?.removeFromParent();
    mudField = null;
    _stormZone?.removeFromParent();
    _stormZone = null;
    _defenseField?.removeFromParent();
    _defenseField = null;
    defenseMap = null;
    _fitCamera();
    defense.value = null;
    for (final tower in towers.values) {
      tower.removeFromParent();
    }
    towers.clear();
    credits.value = 0;
    flagMatch = null;
    _botRespawns.clear();
    _respawnTimer = 0;
    respawnSeconds.value = 0;
    myTank?.removeFromParent();
    myTank = null;
    for (final tank in remoteTanks.values) {
      tank.removeFromParent();
    }
    remoteTanks.clear();
    for (final bullet in bullets.values) {
      bullet.removeFromParent();
    }
    bullets.clear();
    _tracks?.clear();
    for (final bot in botTanks.values) {
      bot.removeFromParent();
    }
    botTanks.clear();
    for (final extra in _extras) {
      extra.removeFromParent();
    }
    _extras.clear();
    powerUps.clear();
    smokes.clear();
    mines.clear();
    shieldSeconds.value = 0;
    drones.clear();
    aircraft.clear();
    _terrainLayer?.removeFromParent();
    _terrainLayer = null;
    terrain = Terrain.flat;
    fuelNotifier.value = 1;
    inventory.clear();
    upgrades.value = const {};
    nearTower.value = null;
    soldierField = null;
    guard.worldReach = GameConfig.worldRadius;
    _blasts.clear();
    specialNotifier.value = null;
    _gone.clear();
    _powerUpSlots = const [];
    rapidFireSeconds.value = 0;
    outcome.value = RoundOutcome.none;
    camera.stop();
    camera.moveTo(Vector2.zero());
    spectatingName.value = null;
    _spectateIndex = 0;
  }

  void _setPhase(GamePhase next) {
    if (phase.value == next) {
      return;
    }
    touch.reset();
    pointerOnHud = false;
    leaveAsked.value = false;
    phase.value = next;
    overlays
      ..removeAll(const [
        OverlayIds.lobby,
        OverlayIds.countdown,
        OverlayIds.hud,
        OverlayIds.spectator,
        OverlayIds.roundOver,
        OverlayIds.closed,
      ])
      ..add(switch (next) {
        GamePhase.lobby => OverlayIds.lobby,
        GamePhase.countdown => OverlayIds.countdown,
        GamePhase.playing => OverlayIds.hud,
        GamePhase.spectating => OverlayIds.spectator,
        GamePhase.roundOver => OverlayIds.roundOver,
        GamePhase.closed => OverlayIds.closed,
      });
  }
}
