part of '../tank_game.dart';

/// Aircraft and enemy drones: helicopters, jets and own air support, their shots and bombs, and the `air` event.
extension TankGameAir on TankGame {
  /// Host of a defense round: a helicopter or a jet comes in over the edge
  /// of the field. A jet heads for the base or for one of the defenders.
  void spawnAircraft(String id, AirKind kind) {
    final map = defenseMap;
    if (map == null) {
      return;
    }
    final Vector2 goal;
    if (kind == AirKind.jet) {
      final defenders = [
        for (final tank in _allTanks)
          if (tank.team == 1 && tank.hp > 0) tank.position,
      ];
      goal = defenders.isNotEmpty && random.nextDouble() < 0.4
          ? defenders[random.nextInt(defenders.length)].clone()
          : map.base.clone();
    } else {
      goal = map.base.clone();
    }
    // In over the same edge the road comes from, somewhere near it.
    final margin = kind == AirKind.jet ? 160.0 : 40.0;
    final side = (random.nextDouble() * 2 - 1) * 300;
    final entry = map.entry;
    final from = entry.x.abs() >= DefenseMap.halfWidth - 1
        ? Vector2(
            entry.x.sign * (DefenseMap.halfWidth + margin),
            (entry.y + side).clamp(
              -DefenseMap.halfHeight,
              DefenseMap.halfHeight,
            ),
          )
        : Vector2(
            (entry.x + side).clamp(-DefenseMap.halfWidth, DefenseMap.halfWidth),
            entry.y.sign * (DefenseMap.halfHeight + margin),
          );
    final plane = Aircraft(
      unitId: id,
      kind: kind,
      position: from,
      angle: TankGame._headingFrom(from, goal),
      goal: goal,
    );
    aircraft[id] = plane;
    _extras.add(plane);
    world.add(plane);
    _announceAircraft(kind);
  }

  /// Host of a defense round: the base sends a helicopter of its own, or a
  /// jet that bombs the enemies closest to the base.
  void spawnSupport(String id, AirKind kind) {
    final map = defenseMap;
    if (map == null) {
      return;
    }
    final Aircraft plane;
    if (kind == AirKind.jet) {
      final goal = supportTarget(map.base, double.infinity)?.position.clone();
      if (goal == null) {
        return;
      }
      // In from behind the base, over the enemies and out the far side.
      final back = (map.base - goal);
      final from =
          goal +
          (back.length2 < 1 ? Vector2(1, 0) : back.normalized()) *
              (back.length + 900);
      plane = Aircraft(
        unitId: id,
        kind: kind,
        position: from,
        angle: TankGame._headingFrom(from, goal),
        goal: goal,
      );
    } else {
      // Lifts off from the base.
      final from = map.base + Vector2(0, -DefenseMap.baseRadius);
      plane = Aircraft(
        unitId: id,
        kind: kind,
        position: from,
        angle: TankGame._headingFrom(from, map.road[map.road.length - 2]),
      );
    }
    aircraft[id] = plane;
    _extras.add(plane);
    world.add(plane);
    _announceAircraft(kind, friendly: true);
  }

  /// What the defenders' own aircraft go for: the enemy tank, else the
  /// enemy soldier, nearest to [from].
  PositionComponent? supportTarget(Vector2 from, double range) =>
      nearestEnemy(from, range) ?? _nearestEnemySoldier(from, range);

  void _announceAircraft(AirKind kind, {bool friendly = false}) {
    if (friendly) {
      showNotice(
        kind == AirKind.jet
            ? tr('EIGENER LUFTSCHLAG IM ANFLUG', 'OWN AIR STRIKE INBOUND')
            : tr('LUFTUNTERSTÜTZUNG IM ANFLUG', 'AIR SUPPORT INBOUND'),
      );
      AudioService.play('go', volume: 0.5);
      return;
    }
    showNotice(
      kind == AirKind.jet
          ? tr('LUFTANGRIFF!', 'AIR RAID!')
          : tr('HUBSCHRAUBER IM ANFLUG', 'HELICOPTER INBOUND'),
    );
    AudioService.play('tick');
  }

  /// Host of a defense round: a kamikaze drone sets off from the start of
  /// the road after the defenders.
  void spawnEnemyDrone(String id) {
    final map = defenseMap;
    if (map == null) {
      return;
    }
    final drone = Drone(
      droneId: id,
      ownerId: id,
      color: GameConfig.teamColors[2],
      position: map.entry.clone(),
      angle: TankGame._headingFrom(map.entry, map.base),
      life: GameConfig.enemyDroneSeconds,
    );
    drones[id] = drone;
    _extras.add(drone);
    world.add(drone);
  }

  /// The host's aircraft [plane] took [damage] from [bullet].
  void aircraftHit(Aircraft plane, Bullet bullet, double damage) {
    net.send(
      NetEvent.hit,
      HitPayload(
        id: plane.unitId,
        shooterId: bullet.ownerId,
        bulletId: bullet.bulletId,
        hp: max(0, plane.hp),
      ).toJson(),
    );
    showHit(plane.position, damage, mine: bullet.ownerId == myId);
    AudioService.play('hit', distance: _distanceToView(plane.position));
    if (plane.hp <= 0) {
      net.send(
        NetEvent.air,
        plane.state(hp: 0, killer: bullet.ownerId).toJson(),
      );
      _downAircraft(plane, bullet.ownerId);
    }
  }

  void _downAircraft(Aircraft plane, String? killer) {
    final activeRound = round;
    if (activeRound == null ||
        !activeRound.destroyedEnemies.add(plane.unitId)) {
      return;
    }
    _recordKill(plane.unitId, killer);
    world.add(
      Explosion(
        position: plane.position.clone(),
        color: const Color(0xFFFFB300),
      ),
    );
    addCrater(plane.position, 26);
    shakeAt(plane.position, 9);
    AudioService.play('explosion', distance: _distanceToView(plane.position));
    aircraft.remove(plane.unitId);
    plane.removeFromParent();
  }

  /// The host's jet flew off the field after its run.
  void aircraftLeft(Aircraft plane) {
    net.send(NetEvent.air, plane.state(hp: -1).toJson());
    round?.destroyedEnemies.add(plane.unitId);
    aircraft.remove(plane.unitId);
    plane.removeFromParent();
  }

  void _onAir(AirPayload payload) {
    final activeRound = round;
    if (activeRound == null ||
        !activeRound.defense ||
        !(activeRound.isEnemy(payload.unit) ||
            activeRound.isFriendlyAir(payload.unit)) ||
        activeRound.destroyedEnemies.contains(payload.unit)) {
      return;
    }
    final known = aircraft[payload.unit];
    if (payload.hp <= 0) {
      if (payload.hp < 0) {
        activeRound.destroyedEnemies.add(payload.unit);
        aircraft.remove(payload.unit);
        known?.removeFromParent();
      } else if (known != null) {
        _downAircraft(known, payload.killer);
      } else {
        activeRound.destroyedEnemies.add(payload.unit);
        _recordKill(payload.unit, payload.killer);
      }
      return;
    }
    if (known != null) {
      known.applyState(payload);
      return;
    }
    final kind =
        AirKind.values[payload.kind.clamp(0, AirKind.values.length - 1)];
    final plane = Aircraft(
      unitId: payload.unit,
      kind: kind,
      position: Vector2(payload.x, payload.y),
      angle: payload.angle,
      remote: true,
    )..applyState(payload);
    aircraft[payload.unit] = plane;
    _extras.add(plane);
    world.add(plane);
    _announceAircraft(kind, friendly: plane.friendly);
  }

  /// The host's helicopter fires a rocket along [direction].
  void fireAircraft(Aircraft plane, Vector2 direction) {
    final bulletId = '${plane.unitId}-${_bulletCounter++}';
    final start = plane.position + direction * 22;
    _spawnBullet(
      bulletId: bulletId,
      ownerId: plane.unitId,
      position: start,
      direction: direction,
      color: GameConfig.teamColors[plane.side],
      speed: GameConfig.helicopterShotSpeed,
      damage: GameConfig.helicopterDamage,
    );
    net.send(
      NetEvent.shoot,
      ShootPayload(
        id: plane.unitId,
        bulletId: bulletId,
        x: start.x,
        y: start.y,
        dx: direction.x,
        dy: direction.y,
        air: true,
      ).toJson(),
    );
    AudioService.play(
      'autocannon',
      volume: 0.5,
      distance: _distanceToView(plane.position),
    );
  }

  /// The host's jet is over its target: a string of bombs along its path.
  void dropBombs(Aircraft plane) {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < GameConfig.jetBombs; i++) {
      final at =
          plane.goal +
          plane.heading * ((i - (GameConfig.jetBombs - 1) / 2) * 80);
      final payload = ArtilleryPayload(
        id: plane.unitId,
        strikeId: '${plane.unitId}-b$i',
        x: at.x,
        y: at.y,
        at: now + 700 + i * 160,
      );
      _addArtillery(payload);
      net.send(NetEvent.artillery, payload.toJson());
    }
  }
}
