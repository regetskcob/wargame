import 'dart:async';
import 'dart:async' as async;
import 'dart:math';
import 'dart:ui' show Color;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../app/overlay_ids.dart';
import '../audio_service.dart';
import '../db/score_service.dart';
import '../game_config.dart';
import '../net/net_events.dart';
import '../net/net_service.dart';
import '../net/payloads/death_payload.dart';
import '../net/payloads/hit_payload.dart';
import '../net/payloads/lobby_presence.dart';
import '../net/payloads/obstacle_payload.dart';
import '../net/payloads/soldier_payload.dart';
import '../net/payloads/power_up_payload.dart';
import '../net/payloads/round_start_payload.dart';
import '../net/payloads/ship_state_payload.dart';
import '../net/payloads/shoot_payload.dart';
import 'components/aim_overlay.dart';
import 'components/asteroid_field.dart';
import 'components/effects.dart';
import 'components/mud_field.dart';
import 'components/obstacle.dart';
import 'map_theme.dart';
import 'components/bullet.dart';
import 'components/explosion.dart';
import 'components/player_ship.dart';
import 'components/power_up.dart';
import 'components/smoke_cloud.dart';
import 'components/remote_ship.dart';
import 'components/starfield.dart';
import 'components/storm_zone.dart';
import 'game_phase.dart';
import 'bot_brain.dart';
import 'components/soldier.dart';
import 'kill_feed.dart';
import 'components/ship_base.dart';
import 'components/wreck.dart';
import 'round_stats.dart';
import 'tank_stats.dart';
import 'touch_input.dart';
import 'round_state.dart';

class SpaceGame extends FlameGame
    with HasKeyboardHandlerComponents, HasCollisionDetection {
  SpaceGame({required this.net, required this.myId, required this.scoreService})
    : super(
        camera: CameraComponent.withFixedResolution(width: 960, height: 540),
      );

  final NetService net;
  final String myId;
  final ScoreService scoreService;

  final phase = ValueNotifier<GamePhase>(GamePhase.lobby);
  final roster = ValueNotifier<List<LobbyPresence>>([]);
  late final hpNotifier = ValueNotifier<double>(myMaxHp);
  final aliveCount = ValueNotifier<int>(0);

  /// On-screen controls: shown on phones and tablets, or after the first touch.
  final touchMode = ValueNotifier<bool>(
    defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android,
  );
  final touch = TouchInput();

  /// Mouse position in widget pixels, null until a mouse is seen. The turret
  /// follows it.
  Vector2? pointer;

  TrackLayer? _tracks;

  /// How the local player came out of the last round, for the end screens.
  final outcome = ValueNotifier<RoundOutcome>(RoundOutcome.none);
  final _extras = <Component>[];

  /// Seconds of rapid fire left, and the last crate the player picked up.
  final rapidFireSeconds = ValueNotifier<int>(0);
  final notice = ValueNotifier<String?>(null);
  async.Timer? _noticeTimer;

  List<PowerUpSlot> _powerUpSlots = const [];
  final powerUps = <int, PowerUp>{};
  final _gone = <int>{};
  final smokes = <SmokeCloud>[];
  final winnerName = ValueNotifier<String?>(null);
  RoundStats roundStats = RoundStats();
  final killFeed = ValueNotifier<List<KillEntry>>(const []);

  /// Computer controlled tanks this client simulates, and how many to add to
  /// the next round.
  final botShips = <String, PlayerShip>{};
  final botCount = ValueNotifier<int>(0);

  /// Team wanted in the lobby (0 for any) and the one given for the round.
  int teamPick = 0;
  int myTeam = 0;

  /// Whether the next round starts with red against blue.
  final teamMode = ValueNotifier<bool>(false);
  final spectatingName = ValueNotifier<String?>(null);

  String myName = 'Panzer-${1000 + Random().nextInt(9000)}';
  int myColorIndex = Random().nextInt(GameConfig.styleCount);

  RoundState? round;

  TankStats get myStats => TankStats.of(GameConfig.typeOf(myColorIndex));
  double get myMaxHp => myStats.maxHp;

  TankStats _statsOf(String playerId) {
    return TankStats.of(GameConfig.typeOf(_styleFor(playerId)));
  }

  /// Distance from the middle of the screen, to fade out far away sounds.
  double _distanceToView(Vector2 point) =>
      point.distanceTo(camera.viewfinder.position);
  PlayerShip? myShip;
  final remoteShips = <String, RemoteShip>{};
  final bullets = <String, Bullet>{};

  AsteroidField? _asteroidField;
  SoldierField? soldierField;

  /// Soldiers this player has run over in the current round.
  final soldiersRunOver = ValueNotifier<int>(0);
  Starfield? _ground;
  MudField? mudField;

  /// Map picked in the lobby, null for a random one.
  final mapChoice = ValueNotifier<int?>(null);
  final mapName = ValueNotifier<String>(MapTheme.forest.name);
  StormZone? _stormZone;
  int _bulletCounter = 0;
  int _spectateIndex = 0;
  int _lastTick = -1;
  double _engineTimer = 0;

  @override
  Future<void> onLoad() async {
    _setGround(MapTheme.forest);
    _tracks = TrackLayer();
    world.add(_tracks!);
    world.add(AimOverlay());
    net
      ..onShipState = _onShipState
      ..onShoot = _onShoot
      ..onHit = _onHit
      ..onDeath = _onDeath
      ..onPickup = _onPickup
      ..onSmoke = _onSmoke
      ..onObstacle = _onObstacle
      ..onSoldier = _onSoldier
      ..onRoundStart = _onRoundStart
      ..onRosterChanged = _onRosterChanged
      ..onPeerLeft = _onPeerLeft;
    await net.connect(_presencePayload());
    overlays.add(OverlayIds.lobby);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final activeRound = round;
    if (phase.value == GamePhase.countdown && activeRound != null) {
      final remainingMs =
          activeRound.startedAt - DateTime.now().millisecondsSinceEpoch;
      final seconds = (remainingMs / 1000).ceil();
      if (seconds > 0 && seconds != _lastTick) {
        _lastTick = seconds;
        AudioService.play('tick');
      }
      if (remainingMs <= 0) {
        _lastTick = -1;
        _setPhase(GamePhase.playing);
        AudioService.play('go');
      }
    }
    _updatePowerUps();
    _engineTimer += dt;
    if (_engineTimer >= 0.1) {
      _engineTimer = 0;
      final ship = myShip;
      if (phase.value == GamePhase.playing && ship != null) {
        unawaited(AudioService.engine(ship.load.abs()));
      } else {
        unawaited(AudioService.stopEngine());
      }
    }
  }

  LobbyPresence _presencePayload() {
    return LobbyPresence(
      id: myId,
      name: myName,
      colorIndex: myColorIndex,
      phase: phase.value.name,
      team: phase.value == GamePhase.lobby ? teamPick : myTeam,
      seed: round?.seed,
      startedAt: round?.startedAt,
    );
  }

  Future<void> pushPresence() => net.updatePresence(_presencePayload());

  void setTeamPick(int team) {
    teamPick = team;
    unawaited(pushPresence());
  }

  /// Teams for a round: picks are honoured, players without a pick fill up
  /// whichever team is smaller.
  Map<String, int> _assignTeams(List<String> ids) {
    if (!teamMode.value) {
      return const {};
    }
    final teams = <String, int>{};
    for (final id in ids) {
      final pick = id == myId ? teamPick : _rosterMember(id)?.team ?? 0;
      if (pick == 1 || pick == 2) {
        teams[id] = pick;
      }
    }
    for (final id in ids) {
      if (teams.containsKey(id)) {
        continue;
      }
      final red = teams.values.where((t) => t == 1).length;
      final blue = teams.values.where((t) => t == 2).length;
      teams[id] = red <= blue ? 1 : 2;
    }
    return teams;
  }

  void setPilot({required String name, required int colorIndex}) {
    myName = name.trim().isEmpty ? myName : name.trim();
    myColorIndex = colorIndex;
    unawaited(pushPresence());
  }

  static final _liveMatchPhases = {
    GamePhase.countdown.name,
    GamePhase.playing.name,
  };

  LobbyPresence? get liveMatch {
    for (final member in roster.value) {
      if (member.inMatch && _liveMatchPhases.contains(member.phase)) {
        return member;
      }
    }
    return null;
  }

  void _setGround(MapTheme theme) {
    _ground?.removeFromParent();
    _ground = Starfield(theme);
    world.add(_ground!);
    mapName.value = theme.name;
  }

  void startRound() {
    if (phase.value != GamePhase.lobby) {
      return;
    }
    final ids = <String>{
      myId,
      for (final member in roster.value)
        if (member.phase == GamePhase.lobby.name) member.id,
    }.toList();
    final bots = <String, int>{
      for (var i = 1; i <= botCount.value; i++)
        'cpu-$i': Random().nextInt(GameConfig.styleCount),
    };
    ids
      ..addAll(bots.keys)
      ..sort();
    final payload = RoundStartPayload(
      seed: switch (mapChoice.value) {
        final map? => MapTheme.seedFor(Random().nextInt(1 << 30), map),
        null => Random().nextInt(1 << 31),
      },
      startedAt:
          DateTime.now().millisecondsSinceEpoch +
          GameConfig.countdownSeconds * 1000,
      participants: ids,
      teams: _assignTeams(ids),
      bots: bots,
      botHost: bots.isEmpty ? null : myId,
    );
    net.send(NetEvent.roundStart, payload.toJson());
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
        if (member.inMatch && _liveMatchPhases.contains(member.phase))
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
        for (final member in roster.value)
          if (member.inMatch && member.team > 0) member.id: member.team,
      },
    );
    _applyRoundStart(payload);
  }

  void _onRoundStart(RoundStartPayload payload) {
    if (phase.value == GamePhase.lobby) {
      _applyRoundStart(payload);
      return;
    }
    final activeRound = round;
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

  void _applyRoundStart(RoundStartPayload payload) {
    _clearWorld();
    final activeRound = RoundState(
      seed: payload.seed,
      startedAt: payload.startedAt,
      participants: List.of(payload.participants)..sort(),
      teams: payload.teams,
      bots: payload.bots,
      botHost: payload.botHost,
    );
    myTeam = payload.teams[myId] ?? 0;
    killFeed.value = const [];
    roundStats = RoundStats();
    round = activeRound;
    _asteroidField = AsteroidField(seed: payload.seed);
    _setGround(_asteroidField!.theme);
    _stormZone = StormZone(startedAt: payload.startedAt);
    _powerUpSlots = PowerUpSlot.schedule(payload.seed);
    world.add(_asteroidField!);
    soldierField = SoldierField(
      seed: payload.seed,
      startedAt: payload.startedAt,
    );
    _extras.add(soldierField!);
    world.add(soldierField!);
    soldiersRunOver.value = 0;
    world.add(_stormZone!);
    mudField = MudField(seed: payload.seed, theme: _asteroidField!.theme);
    world.add(mudField!);
    for (var i = 0; i < activeRound.participants.length; i++) {
      final id = activeRound.participants[i];
      final slotAngle = 2 * pi * i / activeRound.participants.length;
      final spawn = Vector2(cos(slotAngle), sin(slotAngle))
        ..scale(GameConfig.spawnRadius);
      final facing = atan2(-spawn.x, spawn.y);
      final name = _nameFor(id);
      final colorIndex = _styleFor(id);
      final color = GameConfig.colorOf(colorIndex);
      final tankType = GameConfig.typeOf(colorIndex);
      if (id == myId) {
        final ship = PlayerShip(
          playerId: id,
          playerName: name,
          shipColor: color,
          tankType: tankType,
          position: spawn,
          angle: facing,
        );
        myShip = ship;
        ship.team = activeRound.teamOf(id);
        world.add(ship);
        camera.follow(ship, snap: true);
      } else if (activeRound.isBot(id) && activeRound.botHost == myId) {
        final controls = TouchInput();
        final ship = PlayerShip(
          playerId: id,
          playerName: name,
          shipColor: color,
          tankType: tankType,
          position: spawn,
          angle: facing,
          controls: controls,
        );
        ship.team = activeRound.teamOf(id);
        botShips[id] = ship;
        world.add(ship);
        final brain = BotBrain(ship: ship, controls: controls);
        _extras.add(brain);
        world.add(brain);
      } else {
        final ship = RemoteShip(
          playerId: id,
          playerName: name,
          shipColor: color,
          tankType: tankType,
          position: spawn,
          angle: facing,
        );
        remoteShips[id] = ship;
        ship.team = activeRound.teamOf(id);
        world.add(ship);
      }
    }
    hpNotifier.value = myMaxHp;
    aliveCount.value = activeRound.alive.length;
    winnerName.value = null;
    if (activeRound.participants.contains(myId)) {
      _setPhase(GamePhase.countdown);
    } else {
      _setPhase(GamePhase.spectating);
      _spectateByIndex(0);
    }
    unawaited(pushPresence());
  }

  LobbyPresence? _rosterMember(String id) {
    for (final member in roster.value) {
      if (member.id == id) {
        return member;
      }
    }
    return null;
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
    final viewer = phase.value == GamePhase.playing ? myShip : null;
    final viewerInside =
        viewer == null || smokes.any((cloud) => cloud.covers(viewer.position));
    for (final ship in remoteShips.values) {
      ship.hidden =
          viewer != null &&
          !viewerInside &&
          smokes.any((cloud) => cloud.covers(ship.position));
    }
  }

  void collectPowerUp(PowerUp crate) {
    final ship = myShip;
    if (ship == null || phase.value != GamePhase.playing || ship.hp <= 0) {
      return;
    }
    final slot = crate.slot;
    if (_gone.contains(slot.id)) {
      return;
    }
    _gone.add(slot.id);
    powerUps.remove(slot.id);
    crate.removeFromParent();
    net.send(
      NetEvent.pickup,
      PickupPayload(id: myId, powerUpId: slot.id).toJson(),
    );
    switch (slot.type) {
      case PowerUpType.repair:
        ship.hp = min(ship.stats.maxHp, ship.hp + GameConfig.repairAmount);
        hpNotifier.value = ship.hp;
      case PowerUpType.rapidFire:
        ship.rapidFireLeft = GameConfig.rapidFireSeconds;
        rapidFireSeconds.value = GameConfig.rapidFireSeconds.ceil();
      case PowerUpType.smoke:
        _addSmoke(ship.position.clone());
        net.send(
          NetEvent.smoke,
          SmokePayload(
            id: myId,
            x: ship.position.x,
            y: ship.position.y,
          ).toJson(),
        );
    }
    AudioService.play('go', volume: 0.5);
    _noticeTimer?.cancel();
    notice.value = slot.type.label;
    _noticeTimer = async.Timer(
      const Duration(seconds: 2),
      () => notice.value = null,
    );
  }

  void _addSmoke(Vector2 at) {
    final cloud = SmokeCloud(position: at);
    smokes.add(cloud);
    _extras.add(cloud);
    world.add(cloud);
  }

  void _onPickup(PickupPayload payload) {
    _gone.add(payload.powerUpId);
    powerUps.remove(payload.powerUpId)?.removeFromParent();
  }

  void _onSmoke(SmokePayload payload) {
    if (round == null) {
      return;
    }
    _addSmoke(Vector2(payload.x, payload.y));
  }

  void fireLocalBullet() {
    final ship = myShip;
    if (ship != null) {
      fireFrom(ship);
    }
  }

  /// Fires the gun of [ship], which is the player's tank or one of the bots
  /// this client runs.
  void fireFrom(PlayerShip ship) {
    final ownerId = ship.playerId;
    final stats = ship.stats;
    final bulletDirection = ship.turretDirection;
    final side = Vector2(-bulletDirection.y, bulletDirection.x);
    for (var barrel = 0; barrel < stats.barrels; barrel++) {
      final offset = (barrel - (stats.barrels - 1) / 2) * 13;
      final bulletId = '$ownerId-${_bulletCounter++}';
      if (ship == myShip) {
        roundStats.shots++;
      }
      final start =
          ship.position +
          bulletDirection * (GameConfig.shipRadius + 16) +
          side * offset;
      _spawnBullet(
        bulletId: bulletId,
        ownerId: ownerId,
        position: start,
        direction: bulletDirection,
        color: ship.shipColor,
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
        ).toJson(),
      );
    }
    ship.fireEffects();
    AudioService.play(
      stats.sound,
      volume: 0.8,
      distance: ship == myShip ? null : _distanceToView(ship.position),
    );
  }

  void _onShoot(ShootPayload payload) {
    final activeRound = round;
    if (activeRound == null || !activeRound.alive.contains(payload.id)) {
      return;
    }
    final owner = remoteShips[payload.id];
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
      color: owner?.shipColor ?? const Color(0xFFFFFFFF),
    );
  }

  void _spawnBullet({
    required String bulletId,
    required String ownerId,
    required Vector2 position,
    required Vector2 direction,
    required Color color,
  }) {
    final stats = _statsOf(ownerId);
    final bullet = Bullet(
      bulletId: bulletId,
      ownerId: ownerId,
      position: position.clone(),
      velocity: direction.normalized()..scale(stats.bulletSpeed),
      color: color,
      damage: stats.damage,
    );
    bullets[bulletId] = bullet;
    world.add(bullet);
  }

  void _removeBullet(String bulletId) {
    bullets[bulletId]?.removeFromParent();
  }

  void _onShipState(ShipStatePayload payload) {
    final ship = remoteShips[payload.id];
    if (ship != null) {
      ship.applyState(payload);
      return;
    }
    final activeRound = round;
    if (activeRound == null || !activeRound.alive.contains(payload.id)) {
      return;
    }
    final newShip = RemoteShip(
      playerId: payload.id,
      playerName: _nameFor(payload.id),
      shipColor: GameConfig.colorOf(_styleFor(payload.id)),
      tankType: GameConfig.typeOf(_styleFor(payload.id)),
      position: Vector2(payload.x, payload.y),
      angle: payload.rotation,
    );
    newShip.team = activeRound.teamOf(payload.id);
    remoteShips[payload.id] = newShip;
    world.add(newShip);
  }

  void _onHit(HitPayload payload) {
    _removeBullet(payload.bulletId);
    final ship = remoteShips[payload.id];
    if (ship != null) {
      if (payload.shooterId == myId) {
        registerHit(ship.hp - payload.hp);
      }
      ship
        ..hp = payload.hp
        ..flash();
      AudioService.play(
        'hit',
        volume: 0.8,
        distance: _distanceToView(ship.position),
      );
    }
  }

  /// A shell of the local player hit a tank for [damage].
  void registerHit(double damage) {
    roundStats.hits++;
    roundStats.damage += max(0.0, damage);
  }

  double get _secondsIntoRound {
    final started = round?.startedAt;
    return started == null
        ? 0
        : (DateTime.now().millisecondsSinceEpoch - started) / 1000;
  }

  void _onDeath(DeathPayload payload) {
    _recordKill(payload.id, payload.killerId);
    _handleRemoteDeath(payload.id, explode: true);
  }

  void onLocalDeath(String? killerId) {
    final ship = myShip;
    if (ship == null) {
      return;
    }
    net.send(
      NetEvent.death,
      DeathPayload(id: myId, killerId: killerId).toJson(),
    );
    _recordKill(myId, killerId);
    roundStats.finish(_secondsIntoRound);
    round?.alive.remove(myId);
    world.add(
      Explosion(position: ship.position.clone(), color: ship.shipColor),
    );
    _addWreck(ship);
    AudioService.play('explosion');
    outcome.value = RoundOutcome.lost;
    ship.removeFromParent();
    myShip = null;
    aliveCount.value = round?.alive.length ?? 0;
    _setPhase(GamePhase.spectating);
    _spectateByIndex(0);
    unawaited(pushPresence());
    _checkRoundEnd();
  }

  /// World position the mouse points at, from the fixed 960 x 540 viewport.
  Vector2? pointerWorld() {
    final screen = pointer;
    final canvas = canvasSize;
    if (screen == null || canvas.x <= 0 || canvas.y <= 0) {
      return null;
    }
    final scale = min(canvas.x / 960, canvas.y / 540);
    return camera.viewfinder.position + (screen - canvas / 2) / scale;
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

  /// A tank of this client drove over [soldier]: show it and tell the others.
  void runOver(Soldier soldier, String byId) {
    if (soldier.dead) {
      return;
    }
    _killSoldier(soldier, byId);
    net.send(
      NetEvent.soldier,
      SoldierPayload(id: byId, index: soldier.index).toJson(),
    );
  }

  void _onSoldier(SoldierPayload payload) {
    final soldier = soldierField?.soldierAt(payload.index);
    if (soldier != null) {
      _killSoldier(soldier, payload.id);
    }
  }

  void _killSoldier(Soldier soldier, String byId) {
    if (soldier.dead) {
      return;
    }
    soldier.dead = true;
    final at = soldier.position.clone();
    soldierField?.addSplat(at, soldier.index);
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
    final ship = byId == myId ? myShip : remoteShips[byId] ?? botShips[byId];
    ship?.bloodTimer = 4;
    if (byId == myId) {
      soldiersRunOver.value++;
    }
  }

  void _onObstacle(ObstaclePayload payload) {
    final obstacle = _asteroidField?.obstacleAt(payload.index);
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

  void _addWreck(ShipBase ship) {
    final wreck = Wreck(
      position: ship.position.clone(),
      angle: ship.angle,
      tankType: ship.tankType,
      hullSize: ship.size.x,
    );
    _extras.add(wreck);
    world.add(wreck);
  }

  int _styleFor(String id) {
    if (id == myId) {
      return myColorIndex;
    }
    return round?.bots[id] ?? _rosterMember(id)?.colorIndex ?? 0;
  }

  String _nameFor(String id) {
    if (id == myId) {
      return myName;
    }
    final activeRound = round;
    if (activeRound != null && activeRound.isBot(id)) {
      return activeRound.botName(id);
    }
    return _rosterMember(id)?.name ?? 'Panzer';
  }

  String _nameOf(String id) =>
      id == myId ? myName : remoteShips[id]?.playerName ?? _nameFor(id);

  bool isTeammate(String id) => id != myId && sameTeam(myId, id);

  /// True for two different tanks of the same team, never in a free for all.
  bool sameTeam(String a, String b) {
    final activeRound = round;
    if (activeRound == null || a == b) {
      return false;
    }
    final team = activeRound.teamOf(a);
    return team > 0 && team == activeRound.teamOf(b);
  }

  void _recordKill(String victimId, String? killerId) {
    final activeRound = round;
    if (activeRound == null) {
      return;
    }
    if (killerId == myId && victimId != myId) {
      roundStats.kills++;
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

  /// A bot of this client was destroyed.
  void onBotDeath(PlayerShip bot, String? killerId) {
    final activeRound = round;
    if (activeRound == null || !botShips.containsKey(bot.playerId)) {
      return;
    }
    net.send(
      NetEvent.death,
      DeathPayload(id: bot.playerId, killerId: killerId).toJson(),
    );
    _recordKill(bot.playerId, killerId);
    activeRound.alive.remove(bot.playerId);
    aliveCount.value = activeRound.alive.length;
    world.add(Explosion(position: bot.position.clone(), color: bot.shipColor));
    _addWreck(bot);
    AudioService.play('explosion', distance: _distanceToView(bot.position));
    botShips.remove(bot.playerId);
    bot.removeFromParent();
    _refreshSpectateTarget();
    _checkRoundEnd();
  }

  void _onPeerLeft(String id) {
    final ship = remoteShips.remove(id);
    ship?.removeFromParent();
    final activeRound = round;
    if (activeRound != null && activeRound.botHost == id) {
      // Nobody simulates the bots any more.
      for (final botId in activeRound.bots.keys) {
        if (activeRound.alive.contains(botId)) {
          _handleRemoteDeath(botId, explode: false);
        }
      }
    }
    if (activeRound != null && activeRound.alive.remove(id)) {
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
    activeRound.alive.remove(id);
    aliveCount.value = activeRound.alive.length;
    final ship = remoteShips.remove(id);
    if (ship != null) {
      if (explode) {
        world.add(
          Explosion(position: ship.position.clone(), color: ship.shipColor),
        );
        _addWreck(ship);
        AudioService.play(
          'explosion',
          distance: _distanceToView(ship.position),
        );
      }
      ship.removeFromParent();
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
    activeRound.winnerId = winnerId;
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
          remoteShips[winnerId]?.playerName ??
          _rosterMember(winnerId)?.name ??
          'Panzer';
    }
    final won = teamWin ? myTeamWon : winnerId != null && winnerId == myId;
    if (activeRound.participants.contains(myId)) {
      unawaited(
        scoreService.recordRound(name: myName, stats: roundStats, won: won),
      );
    }
    if (won) {
      outcome.value = RoundOutcome.won;
      AudioService.play('win');
    } else if (activeRound.participants.contains(myId)) {
      outcome.value = RoundOutcome.lost;
      AudioService.play('lose');
    }
    if (winnerId != null) {
      final winner = winnerId == myId
          ? myShip
          : remoteShips[winnerId] ?? botShips[winnerId];
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
    if (phase.value != GamePhase.roundOver) {
      return;
    }
    _clearWorld();
    round = null;
    myTeam = 0;
    _setPhase(GamePhase.lobby);
    unawaited(pushPresence());
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
    final targets = [...remoteShips.values, ...botShips.values];
    if (targets.isEmpty) {
      spectatingName.value = null;
      camera.stop();
      return;
    }
    _spectateIndex = index % targets.length;
    final target = targets[_spectateIndex];
    spectatingName.value = target.playerName;
    camera.follow(target, snap: false);
  }

  void _onRosterChanged(List<LobbyPresence> members) {
    roster.value = members;
  }

  void _clearWorld() {
    _setGround(MapTheme.forest);
    _asteroidField?.removeFromParent();
    _asteroidField = null;
    mudField?.removeFromParent();
    mudField = null;
    _stormZone?.removeFromParent();
    _stormZone = null;
    myShip?.removeFromParent();
    myShip = null;
    for (final ship in remoteShips.values) {
      ship.removeFromParent();
    }
    remoteShips.clear();
    for (final bullet in bullets.values) {
      bullet.removeFromParent();
    }
    bullets.clear();
    _tracks?.clear();
    for (final bot in botShips.values) {
      bot.removeFromParent();
    }
    botShips.clear();
    for (final extra in _extras) {
      extra.removeFromParent();
    }
    _extras.clear();
    powerUps.clear();
    smokes.clear();
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
    phase.value = next;
    overlays
      ..removeAll(const [
        OverlayIds.lobby,
        OverlayIds.countdown,
        OverlayIds.hud,
        OverlayIds.spectator,
        OverlayIds.roundOver,
      ])
      ..add(switch (next) {
        GamePhase.lobby => OverlayIds.lobby,
        GamePhase.countdown => OverlayIds.countdown,
        GamePhase.playing => OverlayIds.hud,
        GamePhase.spectating => OverlayIds.spectator,
        GamePhase.roundOver => OverlayIds.roundOver,
      });
  }
}

enum RoundOutcome { none, won, lost }
