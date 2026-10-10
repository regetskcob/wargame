part of '../tank_game.dart';

/// Firing and damage: shells, special weapons, grenades and drones, blasts, hits, and damage to obstacles and trees.
extension TankGameCombat on TankGame {
  /// Damage from something other than a shell to a tank this client runs,
  /// told to the others like a shell hit.
  void _damageLocal(
    PlayerTank tank,
    double amount,
    String ownerId,
    String sourceId,
  ) {
    if (tank.hp <= 0) {
      return;
    }
    tank.applyDamage(amount, killerId: ownerId);
    net.send(
      NetEvent.hit,
      HitPayload(
        id: tank.playerId,
        shooterId: ownerId,
        bulletId: sourceId,
        hp: max(0, tank.hp),
      ).toJson(),
    );
  }

  void fireLocalBullet() {
    final tank = myTank;
    if (tank != null) {
      fireFrom(tank);
    }
  }

  /// Fires the gun of [tank], which is the player's tank or one of the bots
  /// this client runs.
  void fireFrom(PlayerTank tank) {
    final ownerId = tank.playerId;
    final stats = tank.stats;
    final bulletDirection = tank.turretDirection;
    final side = Vector2(-bulletDirection.y, bulletDirection.x);
    for (var barrel = 0; barrel < stats.barrels; barrel++) {
      final offset = (barrel - (stats.barrels - 1) / 2) * 13;
      final bulletId = '$ownerId-${_bulletCounter++}';
      if (tank == myTank) {
        roundStats.shots++;
      }
      final start =
          tank.position +
          bulletDirection * (GameConfig.tankRadius + 16) +
          side * offset;
      final upgraded = tank.gunFactor != 1;
      final damage = stats.damage * tank.gunFactor;
      _spawnBullet(
        bulletId: bulletId,
        ownerId: ownerId,
        position: start,
        direction: bulletDirection,
        color: tank.tankColor,
        damage: damage,
        antiAir: tank.tankType == TankType.habicht,
      );
      net.send(
        NetEvent.shoot,
        ShootPayload(
          id: ownerId,
          bulletId: bulletId,
          x: start.x,
          y: start.y,
          dx: bulletDirection.x,
          dy: bulletDirection.y,
          damage: upgraded ? damage : null,
        ).toJson(),
      );
    }
    tank.fireEffects();
    AudioService.play(
      stats.sound,
      volume: 0.8,
      distance: tank == myTank ? null : _distanceToView(tank.position),
    );
  }

  /// Fires the special weapon of [tank], the player's tank or a local bot.
  void fireSpecial(PlayerTank tank, SpecialWeapon weapon) {
    final ownerId = tank.playerId;
    final direction = tank.turretDirection;
    final start = tank.position + direction * (GameConfig.tankRadius + 10);
    switch (weapon) {
      case SpecialWeapon.grenades || SpecialWeapon.mortar:
        final distance = _lobDistance(tank, weapon);
        final target = tank.position + direction * distance;
        final grenadeId = '$ownerId-g${_bulletCounter++}';
        _launchGrenade(grenadeId, ownerId, start, target, weapon: weapon);
        net.send(
          NetEvent.grenade,
          GrenadePayload(
            id: ownerId,
            grenadeId: grenadeId,
            x: start.x,
            y: start.y,
            tx: target.x,
            ty: target.y,
            weapon: weapon.name,
          ).toJson(),
        );
      case SpecialWeapon.shell:
        return;
      case SpecialWeapon.drone:
        final droneId = '$ownerId-d${_bulletCounter++}';
        final drone = Drone(
          droneId: droneId,
          ownerId: ownerId,
          color: tank.tankColor,
          position: start,
          angle: tank.turretAngle,
        );
        drones[droneId] = drone;
        _extras.add(drone);
        world.add(drone);
    }
    tank.fireEffects();
    AudioService.play(
      'cannon',
      volume: 0.6,
      distance: tank == myTank ? null : _distanceToView(tank.position),
    );
  }

  /// How far a grenade of [tank] flies: to the mouse, to where a bot wants
  /// it, or most of the way for the touch controls.
  double _lobDistance(PlayerTank tank, SpecialWeapon weapon) {
    final wanted = tank.isBot
        ? tank.input.lobDistance
        : touch.aim != null
        ? weapon.range * 0.75
        : pointerWorld()?.distanceTo(tank.position);
    return (wanted ?? weapon.range).clamp(weapon.minRange, weapon.range);
  }

  void _launchGrenade(
    String id,
    String ownerId,
    Vector2 from,
    Vector2 to, {
    SpecialWeapon weapon = SpecialWeapon.grenades,
    double power = 1,
  }) {
    final grenade = Grenade(
      grenadeId: id,
      ownerId: ownerId,
      from: from,
      to: to,
      weapon: weapon,
      power: power,
    );
    final marker = GrenadeMarker(position: to.clone(), weapon: weapon);
    _extras
      ..add(grenade)
      ..add(marker);
    world
      ..add(marker)
      ..add(grenade);
  }

  void _onGrenade(GrenadePayload payload) {
    final activeRound = round;
    final weapon = SpecialWeapon.values.asNameMap()[payload.weapon];
    if (activeRound == null || weapon == null) {
      return;
    }
    final from = Vector2(payload.x, payload.y);
    final to = Vector2(payload.tx, payload.ty);
    final towerIndex = payload.tower;
    if (towerIndex != null) {
      // A mortar emplacement keeps firing while its builder is down.
      final tower = towers['${payload.id}#$towerIndex'];
      if (!activeRound.defense || tower == null) {
        return;
      }
      tower.fired((to - from).normalized());
    } else {
      if (!activeRound.alive.contains(payload.id) ||
          weapon == SpecialWeapon.shell) {
        return;
      }
      remoteTanks[payload.id]?.fireEffects();
    }
    AudioService.play('cannon', volume: 0.5, distance: _distanceToView(from));
    _launchGrenade(
      payload.grenadeId,
      payload.id,
      from,
      to,
      weapon: weapon,
      power: payload.power.clamp(
        1.0,
        TowerKind.howitzer.blast *
            TowerKind.howitzer.damageFactor(TowerKind.maxLevel),
      ),
    );
  }

  void _onDrone(DronePayload payload) {
    if (round == null || _blasts.contains(payload.droneId)) {
      return;
    }
    final known = drones[payload.droneId];
    if (known != null) {
      known.applyState(payload);
      return;
    }
    final drone = Drone(
      droneId: payload.droneId,
      ownerId: payload.id,
      color: _colorFor(payload.id),
      position: Vector2(payload.x, payload.y),
      angle: payload.angle,
      remote: true,
    );
    drones[payload.droneId] = drone;
    _extras.add(drone);
    world.add(drone);
  }

  void _onBlast(BlastPayload payload) {
    if (round == null) {
      return;
    }
    final weapon = SpecialWeapon.values.asNameMap()[payload.weapon];
    if (weapon == null) {
      return;
    }
    detonate(
      ownerId: payload.id,
      blastId: payload.blastId,
      at: Vector2(payload.x, payload.y),
      weapon: weapon,
    );
  }

  /// A grenade or drone of [ownerId] goes off at [at]. Every client damages
  /// its own tanks and reports the hits, the owner's client also takes care
  /// of buildings and soldiers. [announce] tells the others, for drones that
  /// only their owner flies.
  void detonate({
    required String ownerId,
    required String blastId,
    required Vector2 at,
    required SpecialWeapon weapon,
    bool announce = false,
    double power = 1,
  }) {
    if (round == null || !_blasts.add(blastId)) {
      return;
    }
    drones.remove(blastId)?.removeFromParent();
    if (announce) {
      net.send(
        NetEvent.blast,
        BlastPayload(
          id: ownerId,
          blastId: blastId,
          weapon: weapon.name,
          x: at.x,
          y: at.y,
        ).toJson(),
      );
    }
    world.add(Explosion(position: at.clone(), color: weapon.color));
    shakeAt(at, 9);
    AudioService.play('explosion', distance: _distanceToView(at));

    final targets = <PlayerTank>[
      if (phase.value == GamePhase.playing && myTank != null) myTank!,
      ...botTanks.values,
    ];
    for (final tank in targets) {
      if (tank.hp <= 0 ||
          tank.playerId == ownerId ||
          sameTeam(ownerId, tank.playerId)) {
        continue;
      }
      final distance =
          tank.position.distanceTo(at) - GameConfig.tankRadius * 0.6;
      if (distance > weapon.radius) {
        continue;
      }
      final damage = weapon.damageAt(max(0, distance)) * power;
      if (ownerId == myId) {
        registerHit(min(damage, tank.hp));
      }
      AudioService.play('hit');
      tank.applyDamage(damage, killerId: ownerId);
      net.send(
        NetEvent.hit,
        HitPayload(
          id: tank.playerId,
          shooterId: ownerId,
          bulletId: blastId,
          hp: tank.hp,
        ).toJson(),
      );
    }

    // The player who runs the waves keeps the score of every gun, every
    // client notes whose blast caught the enemy's guns for the bounty.
    _blastTowers(ownerId, at, weapon.radius, weapon.damageAt(0) * power);
    if (!runsShooter(ownerId)) {
      return;
    }
    final solids = [
      ...?_coverField?.obstacles,
      ...?_defenseField?.obstacles,
    ].where((o) => o.isMounted);
    for (final obstacle in solids.toList()) {
      final rect = obstacle.toRect();
      final nearest = Vector2(
        at.x.clamp(rect.left, rect.right),
        at.y.clamp(rect.top, rect.bottom),
      );
      if (nearest.distanceTo(at) <= weapon.radius) {
        damageObstacle(
          obstacle,
          weapon.damageAt(nearest.distanceTo(at)) * power,
        );
      }
    }
    _blastSoldiers(ownerId, at, weapon.radius);
    _blastDepots(ownerId, at, weapon.radius, weapon.damageAt(0) * power);
  }

  void _onShoot(ShootPayload payload) {
    final activeRound = round;
    if (activeRound == null) {
      return;
    }
    final towerIndex = payload.tower;
    if (towerIndex != null) {
      final tower = towers['${payload.id}#$towerIndex'];
      if (tower == null) {
        return;
      }
      final direction = Vector2(payload.dx, payload.dy);
      tower.fired(direction);
      AudioService.play(
        'autocannon',
        volume: 0.5,
        distance: _distanceToView(Vector2(payload.x, payload.y)),
      );
      _spawnBullet(
        bulletId: payload.bulletId,
        ownerId: payload.id,
        position: Vector2(payload.x, payload.y),
        direction: direction,
        color: tower.color,
        speed: tower.kind.shotSpeed,
        damage: tower.kind.groundDamageAt(tower.level),
        airDamage: tower.kind.airDamageAt(tower.level),
        antiAir: tower.kind.antiAir,
      );
      return;
    }
    final soldierKey = payload.soldier;
    if (soldierKey != null) {
      final soldier = soldierField?.soldierByKey(soldierKey);
      if (soldier == null || soldier.dead || soldier.ownerId != payload.id) {
        return;
      }
      _soldierShot(
        soldier,
        payload.bulletId,
        Vector2(payload.x, payload.y),
        Vector2(payload.dx, payload.dy),
      );
      return;
    }
    if (payload.air) {
      final friendly = activeRound.isFriendlyAir(payload.id);
      if (!activeRound.defense ||
          !(activeRound.isEnemy(payload.id) || friendly)) {
        return;
      }
      AudioService.play(
        'autocannon',
        volume: 0.5,
        distance: _distanceToView(Vector2(payload.x, payload.y)),
      );
      _spawnBullet(
        bulletId: payload.bulletId,
        ownerId: payload.id,
        position: Vector2(payload.x, payload.y),
        direction: Vector2(payload.dx, payload.dy),
        color: GameConfig.teamColors[friendly ? 1 : 2],
        speed: GameConfig.helicopterShotSpeed,
        damage: GameConfig.helicopterDamage,
      );
      return;
    }
    if (!activeRound.alive.contains(payload.id) ||
        !guard.allowShot(payload.id, x: payload.x, y: payload.y)) {
      return;
    }
    final stats = _statsOf(payload.id);
    final owner = remoteTanks[payload.id];
    owner?.fireEffects();
    AudioService.play(
      _statsOf(payload.id).sound,
      volume: 0.7,
      distance: _distanceToView(Vector2(payload.x, payload.y)),
    );
    _spawnBullet(
      bulletId: payload.bulletId,
      ownerId: payload.id,
      position: Vector2(payload.x, payload.y),
      direction: Vector2(payload.dx, payload.dy),
      color: owner?.tankColor ?? const Color(0xFFFFFFFF),
      // Only defense rounds sell better guns.
      damage: (payload.damage ?? stats.damage).clamp(
        0.0,
        activeRound.defense
            ? stats.damage *
                  UpgradeKind.gun.factorAt(GameConfig.upgradeMaxLevel)
            : stats.damage,
      ),
      antiAir: owner?.tankType == TankType.habicht,
    );
  }

  void _spawnBullet({
    required String bulletId,
    required String ownerId,
    required Vector2 position,
    required Vector2 direction,
    required Color color,
    double? speed,
    double? damage,
    double? airDamage,
    bool antiAir = false,
    bool small = false,
  }) {
    final stats = _statsOf(ownerId);
    final bullet = Bullet(
      bulletId: bulletId,
      ownerId: ownerId,
      position: position.clone(),
      velocity: direction.normalized()..scale(speed ?? stats.bulletSpeed),
      color: color,
      damage: damage ?? stats.damage,
      antiAir: antiAir,
      airDamage: airDamage,
      small: small,
    );
    bullets[bulletId] = bullet;
    world.add(bullet);
  }

  void _removeBullet(String bulletId) {
    bullets[bulletId]?.removeFromParent();
    final mine = mines.remove(bulletId);
    if (mine != null) {
      mineBlast(this, mine.position.clone());
      mine.removeFromParent();
      AudioService.play('explosion', distance: _distanceToView(mine.position));
    }
  }

  void _onHit(HitPayload payload) {
    _removeBullet(payload.bulletId);
    final tank = remoteTanks[payload.id];
    if (tank != null) {
      final hp = guard.checkHit(payload.id, payload.shooterId, hp: payload.hp);
      final damage = tank.hp - hp;
      if (damage > 0) {
        final mine = payload.shooterId == myId;
        showHit(tank.position, damage, mine: mine);
        if (mine) {
          shake(1.5);
        }
      }
      if (payload.shooterId == myId && !replaying.value) {
        registerHit(damage);
      }
      tank
        ..hp = hp
        ..takeHitEffects(damage);
      AudioService.play(
        'hit',
        volume: 0.8,
        distance: _distanceToView(tank.position),
      );
    }
  }

  /// A shell of the local player hit a tank for [damage].
  void registerHit(double damage) {
    roundStats.hits++;
    roundStats.damage += max(0.0, damage);
  }

  /// Applies a shell hit to a building or barrier and tells the other players.
  void damageObstacle(Obstacle obstacle, double damage) {
    final hp = max(0.0, obstacle.hp - damage);
    final destroyed = obstacle.setHp(hp);
    net.send(
      NetEvent.obstacle,
      ObstaclePayload(id: myId, index: obstacle.index, hp: hp).toJson(),
    );
    AudioService.play(
      destroyed ? 'explosion' : 'hit',
      volume: 0.8,
      distance: _distanceToView(obstacle.position),
    );
  }

  /// Whether this client decides what the shells of [ownerId] do to the
  /// ground: its own and those of its CPU tanks, never during a replay.
  bool runsShooter(String ownerId) {
    if (replaying.value) {
      return false;
    }
    if (ownerId == myId || botTanks.containsKey(ownerId)) {
      return true;
    }
    final activeRound = round;
    if (activeRound == null) {
      return false;
    }
    // CPU tanks and the enemies of a defense round, also once destroyed:
    // their soldiers and guns fight on.
    if (activeRound.isBot(ownerId)) {
      return activeRound.botHost == myId;
    }
    if (ownerId.startsWith('inf-')) {
      return infantryHost == myId;
    }
    return false;
  }

  /// Applies a shell hit to a tree and tells the other players.
  void damageTree(Tree tree, double damage) {
    final hp = max(0.0, tree.hp - damage);
    _setTreeHp(tree, hp);
    net.send(
      NetEvent.obstacle,
      ObstaclePayload(id: myId, index: tree.index, hp: hp, tree: true).toJson(),
    );
  }

  void _setTreeHp(Tree tree, double hp) {
    if (!tree.setHp(hp)) {
      return;
    }
    world.add(
      puff(
        position: tree.position.clone(),
        color: tree.theme.treeOuter,
        count: 10,
        lifespan: 1.0,
        speed: (20, 70),
        size: (4, 10),
        opacity: 0.8,
      ),
    );
    AudioService.play(
      'hit',
      volume: 0.6,
      distance: _distanceToView(tree.position),
    );
  }

  void _onObstacle(ObstaclePayload payload) {
    if (payload.depot) {
      _onDepot(payload);
      return;
    }
    if (payload.tree) {
      final tree =
          _coverField?.treeAt(payload.index) ??
          _defenseField?.treeAt(payload.index);
      if (tree != null && payload.hp < tree.hp) {
        _setTreeHp(tree, payload.hp);
      }
      return;
    }
    final obstacle =
        _coverField?.obstacleAt(payload.index) ??
        _defenseField?.obstacleAt(payload.index);
    if (obstacle == null) {
      return;
    }
    final position = obstacle.position.clone();
    final destroyed = obstacle.setHp(payload.hp);
    AudioService.play(
      destroyed ? 'explosion' : 'hit',
      volume: 0.8,
      distance: _distanceToView(position),
    );
  }
}
