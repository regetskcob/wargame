part of '../tank_game.dart';

/// Soldiers on foot: squads and paratroopers, their shots, running them over and the `soldier` and `squad` events.
extension TankGameInfantry on TankGame {
  /// A soldier this client commands fires at [target].
  void fireSoldier(Soldier soldier, PositionComponent target) {
    final owner = soldier.ownerId!;
    soldier.cooldown =
        (soldier.rocket
            ? GameConfig.rocketCooldown
            : GameConfig.rifleCooldown) *
        (0.85 + random.nextDouble() * 0.3);
    final speed = soldier.rocket
        ? GameConfig.rocketSpeed
        : GameConfig.rifleSpeed;
    final flight = target.position.distanceTo(soldier.position) / speed;
    final aim = target.position + velocityOfTarget(target) * flight;
    final spread =
        (random.nextDouble() * 2 - 1) * (soldier.rocket ? 0.05 : 0.1);
    final angle =
        atan2(aim.x - soldier.position.x, -(aim.y - soldier.position.y)) +
        spread;
    final direction = Vector2(sin(angle), -cos(angle));
    final start = soldier.position + direction * 10;
    final bulletId = '$owner-${_bulletCounter++}';
    _soldierShot(soldier, bulletId, start, direction);
    net.send(
      NetEvent.shoot,
      ShootPayload(
        id: owner,
        bulletId: bulletId,
        x: start.x,
        y: start.y,
        dx: direction.x,
        dy: direction.y,
        soldier: soldier.tag,
      ).toJson(),
    );
  }

  void _soldierShot(
    Soldier soldier,
    String bulletId,
    Vector2 start,
    Vector2 direction,
  ) {
    soldier.fired();
    _spawnBullet(
      bulletId: bulletId,
      ownerId: soldier.ownerId!,
      position: start,
      direction: direction,
      color: soldier.rocket ? const Color(0xFFFF8A3D) : const Color(0xFFFFE9A8),
      speed: soldier.rocket ? GameConfig.rocketSpeed : GameConfig.rifleSpeed,
      damage: soldier.rocket ? GameConfig.rocketDamage : GameConfig.rifleDamage,
      small: !soldier.rocket,
    );
    AudioService.play(
      soldier.rocket ? 'cannon' : 'autocannon',
      volume: soldier.rocket ? 0.35 : 0.15,
      distance: _distanceToView(start),
    );
  }

  /// A squad on foot for [tank]: next to the tank, or for [para] dropped
  /// onto the spot it aims at.
  void _deploySquad(PlayerTank tank, {required bool para}) {
    final at = para
        ? _aimPoint(tank, GameConfig.paraDropRange)
        : tank.position - tank.direction * 60;
    _addSquad(
      SquadPayload(
        id: tank.playerId,
        owner: tank.playerId,
        squad: '${tank.playerId}-q${_squadCounter++}',
        x: at.x,
        y: at.y,
        at: DateTime.now().millisecondsSinceEpoch,
        rifles: para ? 0 : GameConfig.squadRifles,
        rockets: para ? GameConfig.paraDropRockets : GameConfig.squadRockets,
        para: para,
      ),
      send: true,
    );
  }

  void _addSquad(SquadPayload payload, {bool send = false}) {
    final field = soldierField;
    if (field == null) {
      return;
    }
    final team = round?.teamOf(payload.owner) ?? 0;
    field.addSquad(
      payload,
      tint: team > 0 ? GameConfig.teamColors[team] : _colorFor(payload.owner),
      // A duel's squads march down the road of their side.
      map: laneMap(payload.lane),
    );
    if (payload.para) {
      AudioService.play(
        'tick',
        distance: _distanceToView(Vector2(payload.x, payload.y)),
      );
    }
    if (send) {
      net.send(NetEvent.squad, payload.toJson());
    }
  }

  void _onSquad(SquadPayload payload) {
    final activeRound = round;
    if (activeRound == null ||
        payload.count > GameConfig.squadRifles + GameConfig.paraDropRockets) {
      return;
    }
    // Squads of the waves and of the base come from the host.
    final wave =
        activeRound.defense &&
        (activeRound.isEnemy(payload.owner) ||
            activeRound.isAlly(payload.owner));
    if (!wave &&
        (!activeRound.alive.contains(payload.owner) ||
            !guard.allowSpecial(payload.owner, consume: true))) {
      return;
    }
    _addSquad(payload);
  }

  Iterable<Soldier> get _enemySoldiers =>
      (soldierField?.all ?? const <Soldier>[]).where(
        (s) =>
            !s.dead &&
            s.isMounted &&
            !s.airborne &&
            (round?.isEnemy(s.ownerId ?? '') ?? false),
      );

  /// In a duel: soldiers of any side other than [team].
  Iterable<Soldier> _hostileSoldiers(int team) =>
      (soldierField?.all ?? const <Soldier>[]).where((s) {
        final side = round?.teamOf(s.ownerId ?? '') ?? 0;
        return !s.dead &&
            s.isMounted &&
            !s.airborne &&
            side != 0 &&
            side != team;
      });

  Soldier? _nearestEnemySoldier(Vector2 from, double range) =>
      _nearestOf(from, range, _enemySoldiers);

  /// Soldiers in a blast of [ownerId] die, except those on its own side.
  void _blastSoldiers(String ownerId, Vector2 at, double radius) {
    for (final soldier in soldierField?.all.toList() ?? <Soldier>[]) {
      if (!soldier.dead &&
          soldier.isMounted &&
          !soldier.airborne &&
          !allied(soldier.ownerId, ownerId) &&
          soldier.position.distanceTo(at) <= radius) {
        runOver(soldier, ownerId);
      }
    }
  }

  /// The player who commands the red and blue squads of a team round: the
  /// first person in the round who is still in the room.
  String? get infantryHost {
    final activeRound = round;
    if (activeRound == null) {
      return null;
    }
    final present = {myId, for (final member in roster.value) member.id};
    for (final id in activeRound.participants) {
      if (!activeRound.isBot(id) && present.contains(id)) {
        return id;
      }
    }
    return null;
  }

  /// A tank of this client drove over [soldier]: show it and tell the others.
  void runOver(Soldier soldier, String byId, {bool crushed = false}) {
    if (soldier.dead) {
      return;
    }
    _killSoldier(soldier, byId, crushed: crushed);
    net.send(
      NetEvent.soldier,
      SoldierPayload(
        id: byId,
        index: soldier.index,
        key: soldier.index < 0 ? soldier.tag : null,
      ).toJson(),
    );
  }

  void _onSoldier(SoldierPayload payload) {
    final key = payload.key;
    final soldier = key == null
        ? soldierField?.soldierAt(payload.index)
        : soldierField?.soldierByKey(key);
    if (soldier == null) {
      return;
    }
    if (payload.raid) {
      _dismiss(soldier);
    } else {
      _killSoldier(soldier, payload.id);
    }
  }

  /// An enemy soldier made it to the base. The player who runs the enemies
  /// takes it off the field and charges the base.
  void _soldierArrived(Soldier soldier) {
    final activeRound = round;
    if (activeRound == null ||
        activeRound.botHost != myId ||
        soldier.dead ||
        !activeRound.isEnemy(soldier.ownerId ?? '')) {
      return;
    }
    final map = defenseMap;
    final march = soldier.march;
    damageBase(
      GameConfig.soldierRaidDamage,
      lane: map == null || march == null ? 0 : max(0, map.lanes.indexOf(march)),
    );
    _dismiss(soldier);
    net.send(
      NetEvent.soldier,
      SoldierPayload(id: myId, key: soldier.tag, raid: true).toJson(),
    );
  }

  void _dismiss(Soldier soldier) {
    soldier
      ..dead = true
      ..removeFromParent();
  }

  void _killSoldier(Soldier soldier, String byId, {bool crushed = true}) {
    if (soldier.dead) {
      return;
    }
    soldier.dead = true;
    if (byId == myId && (round?.isEnemy(soldier.ownerId ?? '') ?? false)) {
      credits.value += GameConfig.creditsPerSoldier;
    }
    final at = soldier.position.clone();
    soldierField?.addSplat(at, stableHash(soldier.tag));
    soldier.removeFromParent();
    world.add(
      puff(
        position: at,
        color: const Color(0xFF8E1010),
        count: 7,
        lifespan: 0.5,
        speed: (10, 45),
        size: (2, 5),
        opacity: 0.8,
      ),
    );
    AudioService.play(
      'squish',
      volume: 0.8,
      distance: byId == myId ? null : _distanceToView(at),
    );
    if (!crushed) {
      return;
    }
    final tank = byId == myId ? myTank : remoteTanks[byId] ?? botTanks[byId];
    tank?.bloodTimer = 4;
    if (byId == myId) {
      soldiersRunOver.value++;
    }
  }
}
