import 'dart:async';
import 'dart:async' as async;
import 'dart:math';
import 'dart:ui' show Canvas, Color, Gradient, Offset, Paint, Size;

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
import '../net/payloads/defense_payload.dart';
import '../net/payloads/hit_payload.dart';
import '../net/payloads/lobby_presence.dart';
import '../net/payloads/obstacle_payload.dart';
import '../net/payloads/soldier_payload.dart';
import '../net/payloads/power_up_payload.dart';
import '../net/payloads/round_start_payload.dart';
import '../net/payloads/ship_state_payload.dart';
import '../net/payloads/shoot_payload.dart';
import '../net/payloads/special_payload.dart';
import '../net/room.dart';
import 'components/aim_overlay.dart';
import 'components/asteroid_field.dart';
import 'components/drone.dart';
import 'components/grenade.dart';
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
import 'defense/defense_brain.dart';
import 'defense/defense_director.dart';
import 'defense/defense_field.dart';
import 'defense/defense_map.dart';
import 'defense/tower.dart';
import 'game_mode.dart';
import 'game_phase.dart';
import 'bot_brain.dart';
import 'components/soldier.dart';
import 'kill_feed.dart';
import 'components/ship_base.dart';
import 'components/wreck.dart';
import 'round_stats.dart';
import 'special_weapon.dart';
import 'tank_stats.dart';
import 'touch_input.dart';
import 'round_state.dart';

class SpaceGame extends FlameGame
    with HasKeyboardHandlerComponents, HasCollisionDetection {
  SpaceGame({required this.net, required this.myId, required this.scoreService})
    : super(camera: CameraComponent());

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

  /// Rounds left in the local tank's magazine.
  late final ammoNotifier = ValueNotifier<int>(myStats.ammo);

  /// Special weapon of the local tank and its charges, null without one.
  final specialNotifier = ValueNotifier<(SpecialWeapon, int)?>(null);

  /// Drones in the air, the local ones and those of other players.
  final drones = <String, Drone>{};

  /// Blasts already applied, since a drone's blast also arrives by message.
  final _blasts = <String>{};

  List<PowerUpSlot> _powerUpSlots = const [];
  final powerUps = <int, PowerUp>{};
  final _gone = <int>{};
  final smokes = <SmokeCloud>[];
  final winnerName = ValueNotifier<String?>(null);
  RoundStats roundStats = RoundStats();
  final killFeed = ValueNotifier<List<KillEntry>>(const []);

  /// Computer controlled tanks this client simulates.
  final botShips = <String, PlayerShip>{};

  /// Alone against CPU tanks, against other people, or together against
  /// waves. Only the host can change it, everybody who joins plays along.
  final mode = ValueNotifier<GameMode>(GameMode.multi);

  void setMode(GameMode value) => mode.value = value;

  /// Whether this player runs the room: picks mode and map and starts the
  /// round. The one who opened the room keeps the role for good. Only when
  /// they are gone does somebody else stand in, until they are back.
  late final isHost = ValueNotifier<bool>(net.isHost);
  double _hostlessFor = 0;
  double _hostClashFor = 0;

  /// Last time anything happened in the room, to close it when it idles.
  DateTime _lastActivity = DateTime.now();

  /// Why the room was closed, shown on the closed screen.
  final closedReason = ValueNotifier<String?>(null);

  /// Defense round: the fixed map, how the base and the waves stand, the
  /// local player's money for guns and every gun on the field.
  DefenseMap? defenseMap;
  DefenseField? _defenseField;
  final defense = ValueNotifier<DefensePayload?>(null);
  final credits = ValueNotifier<int>(0);
  final towers = <String, Tower>{};
  int _towerCounter = 0;

  /// Seconds until the local tank is back after it was destroyed in a
  /// defense round, 0 while it is on the field.
  final respawnSeconds = ValueNotifier<int>(0);
  double _respawnTimer = 0;

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
  double _staleTimer = 0;
  double _engineTimer = 0;

  double _shake = 0;
  double _damageFlash = 0;
  final _shakeRandom = Random();

  /// Rattles the screen. Strengths add up and fade out within a fraction of
  /// a second.
  void shake(double strength) {
    _shake = min(14.0, _shake + strength);
  }

  /// Shakes by [strength], weaker the further [at] is from the middle of the
  /// screen, so far away explosions barely register.
  void shakeAt(Vector2 at, double strength) {
    final distance = _distanceToView(at);
    shake(strength * (1 - (distance / 700).clamp(0.0, 1.0)));
  }

  /// A tank at [at] took [amount] damage from a shell. [mine] marks hits the
  /// local player dealt or took.
  void showHit(Vector2 at, double amount, {required bool mine, Color? color}) {
    world.add(
      DamageNumber(
        position: at + Vector2(0, -GameConfig.shipRadius),
        amount: amount,
        color: color ?? const Color(0xFFFFE08A),
        mine: mine,
      ),
    );
  }

  /// The local tank was hit.
  void onLocalDamage(Vector2 at, double amount) {
    _damageFlash = min(1.0, _damageFlash + 0.35 + amount / 60);
    shake(3 + amount / 4);
    showHit(at, amount, mine: true, color: const Color(0xFFFF6B5A));
  }

  @override
  void render(Canvas canvas) {
    final rattle = _shake > 0.2;
    if (rattle) {
      canvas.save();
      canvas.translate(
        (_shakeRandom.nextDouble() * 2 - 1) * _shake,
        (_shakeRandom.nextDouble() * 2 - 1) * _shake,
      );
    }
    super.render(canvas);
    if (rattle) {
      canvas.restore();
    }
    if (_damageFlash > 0.01) {
      final size = canvasSize;
      final edge = Paint()
        ..shader = Gradient.radial(
          Offset(size.x / 2, size.y / 2),
          size.length / 1.6,
          [
            const Color(0x00D32F2F),
            Color.fromRGBO(211, 47, 47, 0.55 * _damageFlash),
          ],
        );
      canvas.drawRect(Offset.zero & Size(size.x, size.y), edge);
    }
  }

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
      ..onDefense = _onDefense
      ..onTower = _onTower
      ..onGrenade = _onGrenade
      ..onDrone = _onDrone
      ..onBlast = _onBlast
      ..onRoundStart = _onRoundStart
      ..onRosterChanged = _onRosterChanged
      ..onPeerLeft = _onPeerLeft
      ..onClose = _onClose;
    await net.connect(_presencePayload());
    overlays.add(OverlayIds.lobby);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _shake = max(0, _shake - dt * 28);
    _damageFlash = max(0, _damageFlash - dt * 2.5);
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
    _updateRespawn(dt);
    _resupply(dt);
    _staleTimer += dt;
    if (_staleTimer >= 1) {
      _settleHost(_staleTimer);
      _staleTimer = 0;
      _dropSilentTanks();
      _closeWhenIdle();
    }
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
      host: isHost.value,
      owner: net.isHost,
      seed: round?.seed,
      startedAt: round?.startedAt,
      defense: round?.defense ?? false,
      botHost: round?.defense ?? false ? round?.botHost : null,
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

  void _setGround(MapTheme theme, {bool plain = false}) {
    _ground?.removeFromParent();
    _ground = Starfield(theme, plain: plain);
    world.add(_ground!);
    mapName.value = theme.name;
  }

  /// Only the host starts a round. When the host leaves, the role moves on.
  bool get canStart => isHost.value;

  void _setHost(bool value) {
    if (isHost.value == value) {
      return;
    }
    isHost.value = value;
    if (!value && mode.value == GameMode.solo) {
      // Guests always play together, the settings belong to the host.
      mode.value = GameMode.multi;
    }
    unawaited(pushPresence());
  }

  /// Makes sure the room has exactly one host. Presence takes a moment to
  /// travel, so a missing or doubled host is only fixed once it lasts: then
  /// the player with the smallest id stands in, and a stand-in hands back as
  /// soon as the owner of the room returns.
  void _settleHost(double dt) {
    final members = roster.value;
    if (phase.value == GamePhase.closed || !members.any((m) => m.id == myId)) {
      _hostlessFor = _hostClashFor = 0;
      return;
    }
    final hosts = [
      for (final member in members)
        if (member.host) member.id,
    ];
    _hostlessFor = hosts.isEmpty && !isHost.value ? _hostlessFor + dt : 0;
    _hostClashFor = hosts.length > 1 ? _hostClashFor + dt : 0;
    final first = (members.map((m) => m.id).toList()..sort()).first;
    if (_hostlessFor >= GameConfig.hostSettleSeconds && first == myId) {
      _hostlessFor = 0;
      _setHost(true);
    }
    final outranked = members.any(
      (m) => m.host && m.id != myId && (m.owner || m.id.compareTo(myId) < 0),
    );
    // The owner never steps down.
    if (_hostClashFor >= GameConfig.hostSettleSeconds &&
        isHost.value &&
        !net.isHost &&
        outranked) {
      _hostClashFor = 0;
      _setHost(false);
    }
  }

  /// Colour of a player's tank as the lobby previews it: camouflage alone,
  /// one colour per seat when playing with others.
  Color lobbyColorOf(String id, int style) {
    if (!mode.value.withOthers) {
      return GameConfig.colorOf(style);
    }
    final seats = {myId, for (final member in roster.value) member.id}.toList()
      ..sort();
    return GameConfig.playerColor(max(0, seats.indexOf(id)));
  }

  Color _colorFor(String id) {
    final activeRound = round;
    if (activeRound != null && activeRound.distinctColors) {
      final seat = activeRound.participants.indexOf(id);
      if (seat >= 0) {
        return GameConfig.playerColor(seat);
      }
    }
    return GameConfig.colorOf(_styleFor(id));
  }

  void startRound() {
    if (phase.value != GamePhase.lobby || !canStart) {
      return;
    }
    final solo = mode.value == GameMode.solo;
    final defending = mode.value == GameMode.defense;
    final ids = <String>{
      myId,
      if (!solo)
        for (final member in roster.value)
          if (member.phase == GamePhase.lobby.name) member.id,
    }.toList();
    // CPU tanks only exist when playing alone, and then there are always some.
    final botCount = solo
        ? GameConfig.minBots +
              Random().nextInt(GameConfig.maxBots - GameConfig.minBots + 1)
        : 0;
    final bots = <String, int>{
      for (var i = 1; i <= botCount; i++)
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
      teams: defending ? const {} : _assignTeams(ids),
      bots: bots,
      botHost: bots.isEmpty && !defending ? null : myId,
      defense: defending,
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
        if (!live.defense)
          for (final member in roster.value)
            if (member.inMatch && member.team > 0) member.id: member.team,
      },
      defense: live.defense,
      botHost: live.botHost,
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
    _lastActivity = DateTime.now();
    final activeRound = RoundState(
      seed: payload.seed,
      startedAt: payload.startedAt,
      participants: List.of(payload.participants)..sort(),
      teams: payload.teams,
      bots: payload.bots,
      botHost: payload.botHost,
      defense: payload.defense,
    );
    myTeam = activeRound.teamOf(myId);
    killFeed.value = const [];
    roundStats = RoundStats();
    round = activeRound;
    if (activeRound.defense) {
      _setUpDefense(activeRound);
      return;
    }
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
      final color = _colorFor(id);
      final tankType = GameConfig.typeOf(_styleFor(id));
      if (id == myId) {
        _spawnLocalShip(spawn, facing);
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
        _addRemoteShip(id, spawn, facing);
      }
    }
    _enterRound(activeRound);
  }

  void _enterRound(RoundState activeRound) {
    hpNotifier.value = myMaxHp;
    ammoNotifier.value = myStats.ammo;
    specialNotifier.value = null;
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

  PlayerShip _spawnLocalShip(Vector2 at, double facing) {
    final ship = PlayerShip(
      playerId: myId,
      playerName: myName,
      shipColor: _colorFor(myId),
      tankType: GameConfig.typeOf(myColorIndex),
      position: at,
      angle: facing,
    );
    myShip = ship;
    ship.team = round?.teamOf(myId) ?? 0;
    world.add(ship);
    camera.follow(ship, snap: true);
    return ship;
  }

  RemoteShip _addRemoteShip(String id, Vector2 at, double facing) {
    final style = _styleFor(id);
    final ship = RemoteShip(
      playerId: id,
      playerName: _nameFor(id),
      shipColor: _colorFor(id),
      tankType: GameConfig.typeOf(style),
      position: at,
      angle: facing,
    );
    ship.team = round?.teamOf(id) ?? 0;
    remoteShips[id] = ship;
    world.add(ship);
    return ship;
  }

  /// The fixed map of a defense round: road, base and the players in front
  /// of it. The player who runs the enemies also gets the director.
  void _setUpDefense(RoundState activeRound) {
    final map = DefenseMap.forSeed(activeRound.seed);
    defenseMap = map;
    final field = DefenseField(seed: activeRound.seed, map: map);
    _defenseField = field;
    _setGround(field.theme, plain: true);
    world.add(field);
    credits.value = GameConfig.startCredits;
    _towerCounter = 0;
    defense.value = DefensePayload(
      id: activeRound.botHost ?? '',
      hp: GameConfig.baseHp,
      wave: 0,
      nextWaveAt: activeRound.startedAt + GameConfig.firstWaveSeconds * 1000,
    );
    final players = activeRound.participants;
    for (var i = 0; i < players.length; i++) {
      final id = players[i];
      final spawn = map.spawnFor(i, players.length);
      final facing = _headingFrom(spawn, map.road[map.road.length - 2]);
      if (id == myId) {
        _spawnLocalShip(spawn, facing);
      } else {
        _addRemoteShip(id, spawn, facing);
      }
    }
    if (activeRound.botHost == myId) {
      final director = DefenseDirector(startedAt: activeRound.startedAt);
      _extras.add(director);
      world.add(director);
    }
    _enterRound(activeRound);
  }

  static double _headingFrom(Vector2 from, Vector2 to) =>
      atan2(to.x - from.x, -(to.y - from.y));

  /// Host of a defense round: an enemy rolls in at the start of the road.
  void spawnEnemy(String id) {
    final activeRound = round;
    final map = defenseMap;
    if (activeRound == null || map == null) {
      return;
    }
    final style = activeRound.enemyStyle(id);
    final controls = TouchInput();
    final ship =
        PlayerShip(
            playerId: id,
            playerName: activeRound.botName(id),
            shipColor: GameConfig.colorOf(style),
            tankType: GameConfig.typeOf(style),
            position: map.entry.clone(),
            angle: _headingFrom(map.entry, map.road[1]),
            controls: controls,
          )
          ..team = 2
          ..endlessAmmo = true
          ..speedFactor = GameConfig.enemySpeed
          ..fireFactor = GameConfig.enemyFireFactor
          ..syncInterval = GameConfig.enemySyncInterval;
    activeRound.alive.add(id);
    aliveCount.value = activeRound.alive.length;
    botShips[id] = ship;
    world.add(ship);
    final brain = DefenseBrain(ship: ship, controls: controls, map: map);
    _extras.add(brain);
    world.add(brain);
  }

  /// Host: an enemy made it to the base and blows itself up there.
  void raidBase(PlayerShip enemy) {
    if (enemy.hp <= 0) {
      return;
    }
    damageBase(GameConfig.raidDamage * enemy.stats.maxHp / 100);
    enemy.applyDamage(enemy.hp, killerId: null);
  }

  /// Host: enemy fire or a raid wore the base down.
  void damageBase(double amount) {
    final state = defense.value;
    if (state == null || round?.botHost != myId) {
      return;
    }
    publishDefense(state.copyWith(hp: max(0.0, state.hp - amount)));
  }

  /// Host: applies a new state of the base and the waves and sends it.
  void publishDefense(DefensePayload state) {
    _applyDefense(state);
    net.send(NetEvent.defense, state.toJson());
  }

  void _onDefense(DefensePayload payload) {
    if (round?.defense ?? false) {
      _applyDefense(payload);
    }
  }

  void _applyDefense(DefensePayload state) {
    final before = defense.value;
    final base = _defenseField?.headquarters;
    if (before != null && base != null && state.hp < before.hp) {
      base.flash();
      shakeAt(base.position, 4);
      AudioService.play(
        'hit',
        volume: 0.8,
        distance: _distanceToView(base.position),
      );
    }
    base?.hp = state.hp;
    defense.value = state;
    if (before != null &&
        state.wave > 0 &&
        state.nextWaveAt > 0 &&
        before.nextWaveAt == 0) {
      // A wave was beaten off.
      credits.value += GameConfig.waveBonus;
      showNotice('WELLE ${state.wave} ABGEWEHRT  +${GameConfig.waveBonus}');
    } else if (before != null && state.wave > before.wave) {
      showNotice('WELLE ${state.wave} ROLLT AN');
      AudioService.play('go', volume: 0.6);
    }
    if (state.result != DefenseResult.running) {
      _endDefense(won: state.result == DefenseResult.won);
    }
  }

  /// Puts a gun where the local tank stands, if there is money and room.
  void buildTower() {
    final ship = myShip;
    final map = defenseMap;
    if (ship == null || map == null || phase.value != GamePhase.playing) {
      return;
    }
    final mine = towers.values.where((t) => t.ownerId == myId).length;
    final reason = credits.value < GameConfig.towerCost
        ? 'Zu wenig Mittel'
        : mine >= GameConfig.maxTowers
        ? 'Höchstens ${GameConfig.maxTowers} Geschütze'
        : map.whyNotBuild(ship.position, towers.values.map((t) => t.position));
    if (reason != null) {
      showNotice(reason.toUpperCase());
      return;
    }
    credits.value -= GameConfig.towerCost;
    final payload = TowerPayload(
      id: myId,
      index: _towerCounter++,
      x: ship.position.x,
      y: ship.position.y,
    );
    _addTower(payload);
    net.send(NetEvent.tower, payload.toJson());
    AudioService.play('go', volume: 0.5);
  }

  void _onTower(TowerPayload payload) {
    if (round?.defense ?? false) {
      _addTower(payload);
    }
  }

  void _addTower(TowerPayload payload) {
    final tower = Tower(
      ownerId: payload.id,
      index: payload.index,
      color: _colorFor(payload.id),
      position: Vector2(payload.x, payload.y),
    );
    if (towers.containsKey(tower.id)) {
      return;
    }
    towers[tower.id] = tower;
    world.add(tower);
  }

  /// A gun of the local player fires at the enemy it is aimed at.
  void fireTower(Tower tower) {
    final direction = Vector2(sin(tower.turretAngle), -cos(tower.turretAngle));
    final bulletId = '$myId-${_bulletCounter++}';
    final start = tower.position + direction * 28;
    tower.fired(direction);
    _spawnBullet(
      bulletId: bulletId,
      ownerId: myId,
      position: start,
      direction: direction,
      color: tower.color,
      speed: GameConfig.towerBulletSpeed,
      damage: GameConfig.towerDamage,
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
      volume: 0.5,
      distance: _distanceToView(tower.position),
    );
  }

  Iterable<ShipBase> get _allTanks => [
    ?myShip,
    ...remoteShips.values,
    ...botShips.values,
  ];

  ShipBase? _nearest(Vector2 from, double range, bool Function(int) team) {
    ShipBase? best;
    var bestDistance = range;
    for (final ship in _allTanks) {
      if (!ship.isMounted || ship.hp <= 0 || !team(ship.team)) {
        continue;
      }
      final distance = ship.position.distanceTo(from);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = ship;
      }
    }
    return best;
  }

  /// Closest enemy of a defense round within [range] of [from].
  ShipBase? nearestEnemy(Vector2 from, double range) =>
      _nearest(from, range, (team) => team == 2);

  /// Closest player tank within [range] of [from], for the enemies to shoot.
  ShipBase? nearestDefender(Vector2 from, double range) =>
      _nearest(from, range, (team) => team == 1);

  Vector2 velocityOf(ShipBase ship) => switch (ship) {
    final PlayerShip local => local.velocity,
    final RemoteShip remote => remote.velocity,
    _ => Vector2.zero(),
  };

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
    final map = defenseMap;
    if (activeRound == null ||
        map == null ||
        phase.value != GamePhase.playing) {
      return;
    }
    final at = map.spawnFor(
      activeRound.participants.indexOf(myId),
      activeRound.participants.length,
    );
    _spawnLocalShip(at, _headingFrom(at, map.road[map.road.length - 2]));
    activeRound.alive.add(myId);
    aliveCount.value = activeRound.alive.length;
    hpNotifier.value = myMaxHp;
    ammoNotifier.value = myStats.ammo;
    specialNotifier.value = null;
  }

  double _resupplied = 0;

  /// Defense round: the base is the ammo dump. A tank next to it gets its
  /// magazine refilled bit by bit, since no gems lie on this map.
  void _resupply(double dt) {
    final ship = myShip;
    final map = defenseMap;
    if (ship == null || map == null || phase.value != GamePhase.playing) {
      return;
    }
    final near =
        ship.position.distanceTo(map.base) <
        DefenseMap.baseRadius + GameConfig.resupplyReach;
    if (!near || ship.ammo >= ship.stats.ammo) {
      _resupplied = 0;
      return;
    }
    _resupplied += dt * ship.stats.ammo / GameConfig.resupplySeconds;
    if (_resupplied >= 1) {
      final rounds = _resupplied.floor();
      _resupplied -= rounds;
      ship.setAmmo(ship.ammo + rounds);
    }
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

  /// [ship] drove over [crate]: the player's tank or a bot of this client.
  void collectPowerUp(PowerUp crate, PlayerShip ship) {
    final mine = ship == myShip;
    final live =
        phase.value == GamePhase.playing ||
        (!mine && phase.value == GamePhase.spectating);
    if (!live || ship.hp <= 0) {
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
      PickupPayload(id: ship.playerId, powerUpId: slot.id).toJson(),
    );
    switch (slot.type) {
      case PowerUpType.repair:
        ship.hp = min(ship.stats.maxHp, ship.hp + GameConfig.repairAmount);
        if (mine) {
          hpNotifier.value = ship.hp;
        }
      case PowerUpType.rapidFire:
        ship.rapidFireLeft = GameConfig.rapidFireSeconds;
        if (mine) {
          rapidFireSeconds.value = GameConfig.rapidFireSeconds.ceil();
        }
      case PowerUpType.ammo:
        ship.setAmmo(
          ship.ammo + (ship.stats.ammo * GameConfig.ammoRefillShare).ceil(),
        );
      case PowerUpType.grenades || PowerUpType.drone:
        ship.arm(slot.type.weapon!);
      case PowerUpType.smoke:
        _addSmoke(ship.position.clone());
        net.send(
          NetEvent.smoke,
          SmokePayload(
            id: ship.playerId,
            x: ship.position.x,
            y: ship.position.y,
          ).toJson(),
        );
    }
    if (mine) {
      AudioService.play('go', volume: 0.5);
      showNotice(slot.type.label);
    }
  }

  /// Flashes [text] in the middle of the HUD for two seconds.
  void showNotice(String text) {
    _noticeTimer?.cancel();
    notice.value = text;
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

  /// Tanks [id] may shoot at: everybody alive outside its own team.
  Iterable<ShipBase> enemiesOf(String id) sync* {
    final candidates = <ShipBase?>[
      myShip,
      ...remoteShips.values,
      ...botShips.values,
    ];
    for (final ship in candidates) {
      if (ship != null &&
          ship.isMounted &&
          ship.hp > 0 &&
          ship.playerId != id &&
          !sameTeam(id, ship.playerId)) {
        yield ship;
      }
    }
  }

  /// Fires the special weapon of [ship], the player's tank or a local bot.
  void fireSpecial(PlayerShip ship, SpecialWeapon weapon) {
    final ownerId = ship.playerId;
    final direction = ship.turretDirection;
    final start = ship.position + direction * (GameConfig.shipRadius + 10);
    switch (weapon) {
      case SpecialWeapon.grenades:
        final distance = _lobDistance(ship);
        final target = ship.position + direction * distance;
        final grenadeId = '$ownerId-g${_bulletCounter++}';
        _launchGrenade(grenadeId, ownerId, start, target);
        net.send(
          NetEvent.grenade,
          GrenadePayload(
            id: ownerId,
            grenadeId: grenadeId,
            x: start.x,
            y: start.y,
            tx: target.x,
            ty: target.y,
          ).toJson(),
        );
      case SpecialWeapon.drone:
        final droneId = '$ownerId-d${_bulletCounter++}';
        final drone = Drone(
          droneId: droneId,
          ownerId: ownerId,
          color: ship.shipColor,
          position: start,
          angle: ship.turretAngle,
        );
        drones[droneId] = drone;
        _extras.add(drone);
        world.add(drone);
    }
    ship.fireEffects();
    AudioService.play(
      'cannon',
      volume: 0.6,
      distance: ship == myShip ? null : _distanceToView(ship.position),
    );
  }

  /// How far a grenade of [ship] flies: to the mouse, to where a bot wants
  /// it, or most of the way for the touch controls.
  double _lobDistance(PlayerShip ship) {
    final wanted = ship.isBot
        ? ship.input.lobDistance
        : touch.aim != null
        ? GameConfig.grenadeRange * 0.75
        : pointerWorld()?.distanceTo(ship.position);
    return (wanted ?? GameConfig.grenadeRange).clamp(
      GameConfig.grenadeMinRange,
      GameConfig.grenadeRange,
    );
  }

  void _launchGrenade(String id, String ownerId, Vector2 from, Vector2 to) {
    final grenade = Grenade(
      grenadeId: id,
      ownerId: ownerId,
      from: from,
      to: to,
    );
    final marker = GrenadeMarker(position: to.clone());
    _extras
      ..add(grenade)
      ..add(marker);
    world
      ..add(marker)
      ..add(grenade);
  }

  void _onGrenade(GrenadePayload payload) {
    final activeRound = round;
    if (activeRound == null || !activeRound.alive.contains(payload.id)) {
      return;
    }
    final owner = remoteShips[payload.id];
    owner?.fireEffects();
    AudioService.play(
      'cannon',
      volume: 0.5,
      distance: _distanceToView(Vector2(payload.x, payload.y)),
    );
    _launchGrenade(
      payload.grenadeId,
      payload.id,
      Vector2(payload.x, payload.y),
      Vector2(payload.tx, payload.ty),
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

  /// Whether this client simulates the tank [id]: the player or a local bot.
  bool _isLocal(String id) {
    final activeRound = round;
    return id == myId ||
        (activeRound != null &&
            activeRound.isBot(id) &&
            activeRound.botHost == myId);
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

    final targets = <PlayerShip>[
      if (phase.value == GamePhase.playing && myShip != null) myShip!,
      ...botShips.values,
    ];
    for (final ship in targets) {
      if (ship.hp <= 0 ||
          ship.playerId == ownerId ||
          sameTeam(ownerId, ship.playerId)) {
        continue;
      }
      final distance =
          ship.position.distanceTo(at) - GameConfig.shipRadius * 0.6;
      if (distance > weapon.radius) {
        continue;
      }
      final damage = weapon.damageAt(max(0, distance));
      if (ownerId == myId) {
        registerHit(min(damage, ship.hp));
      }
      AudioService.play('hit');
      ship.applyDamage(damage, killerId: ownerId);
      net.send(
        NetEvent.hit,
        HitPayload(
          id: ship.playerId,
          shooterId: ownerId,
          bulletId: blastId,
          hp: ship.hp,
        ).toJson(),
      );
    }

    if (!_isLocal(ownerId)) {
      return;
    }
    final solids = _asteroidField?.obstacles.where((o) => o.isMounted) ?? [];
    for (final obstacle in solids.toList()) {
      final rect = obstacle.toRect();
      final nearest = Vector2(
        at.x.clamp(rect.left, rect.right),
        at.y.clamp(rect.top, rect.bottom),
      );
      if (nearest.distanceTo(at) <= weapon.radius) {
        damageObstacle(obstacle, weapon.damageAt(nearest.distanceTo(at)));
      }
    }
    for (final soldier in soldierField?.soldiers.toList() ?? <Soldier>[]) {
      if (!soldier.dead &&
          soldier.isMounted &&
          soldier.position.distanceTo(at) <= weapon.radius) {
        runOver(soldier, ownerId);
      }
    }
  }

  void _onShoot(ShootPayload payload) {
    final activeRound = round;
    if (activeRound == null) {
      return;
    }
    final towerIndex = payload.tower;
    if (towerIndex != null) {
      final tower = towers['${payload.id}#$towerIndex'];
      final direction = Vector2(payload.dx, payload.dy);
      tower?.fired(direction);
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
        color: tower?.color ?? const Color(0xFFFFFFFF),
        speed: GameConfig.towerBulletSpeed,
        damage: GameConfig.towerDamage,
      );
      return;
    }
    if (!activeRound.alive.contains(payload.id)) {
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
    double? speed,
    double? damage,
  }) {
    final stats = _statsOf(ownerId);
    final bullet = Bullet(
      bulletId: bulletId,
      ownerId: ownerId,
      position: position.clone(),
      velocity: direction.normalized()..scale(speed ?? stats.bulletSpeed),
      color: color,
      damage: damage ?? stats.damage,
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
    if (activeRound == null) {
      return;
    }
    // In a defense round enemies roll in during the round and players come
    // back after they were destroyed.
    final joins =
        activeRound.defense &&
        !activeRound.fallen.contains(payload.id) &&
        (activeRound.isEnemy(payload.id) ||
            activeRound.participants.contains(payload.id));
    if (joins) {
      activeRound.alive.add(payload.id);
      aliveCount.value = activeRound.alive.length;
    }
    if (!activeRound.alive.contains(payload.id)) {
      return;
    }
    _addRemoteShip(
      payload.id,
      Vector2(payload.x, payload.y),
      payload.rotation,
    ).applyState(payload);
  }

  void _onHit(HitPayload payload) {
    _removeBullet(payload.bulletId);
    final ship = remoteShips[payload.id];
    if (ship != null) {
      final damage = ship.hp - payload.hp;
      if (damage > 0) {
        final mine = payload.shooterId == myId;
        showHit(ship.position, damage, mine: mine);
        if (mine) {
          shake(1.5);
        }
      }
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
    if (round?.defense ?? false) {
      // Defenders come back after a short while, the round goes on.
      round?.alive.remove(myId);
      world.add(
        Explosion(position: ship.position.clone(), color: ship.shipColor),
      );
      shake(12);
      _addWreck(ship);
      AudioService.play('explosion');
      ship.removeFromParent();
      myShip = null;
      camera.stop();
      aliveCount.value = round?.alive.length ?? 0;
      _respawnTimer = GameConfig.respawnSeconds;
      respawnSeconds.value = _respawnTimer.ceil();
      return;
    }
    roundStats.finish(_secondsIntoRound);
    round?.alive.remove(myId);
    world.add(
      Explosion(position: ship.position.clone(), color: ship.shipColor),
    );
    shake(12);
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

  /// Pixels per world unit. The shorter side of the window always shows the
  /// same stretch of the world, the longer side simply shows more, so the map
  /// fills the whole window without black bars.
  double get viewScale =>
      min(canvasSize.x, canvasSize.y) / GameConfig.viewShortSide;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    camera.viewfinder.zoom = viewScale;
  }

  /// World position the mouse points at.
  Vector2? pointerWorld() {
    final screen = pointer;
    final canvas = canvasSize;
    if (screen == null || canvas.x <= 0 || canvas.y <= 0) {
      return null;
    }
    return camera.viewfinder.position + (screen - canvas / 2) / viewScale;
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
    final activeRound = round;
    if (activeRound != null && activeRound.isEnemy(id)) {
      return activeRound.enemyStyle(id);
    }
    return activeRound?.bots[id] ?? _rosterMember(id)?.colorIndex ?? 0;
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
    if (killerId == null && activeRound.isEnemy(victimId)) {
      // An enemy that blew itself up at the base, the base bar shows it.
      return;
    }
    if (killerId == myId && victimId != myId) {
      roundStats.kills++;
      if (activeRound.isEnemy(victimId)) {
        credits.value += GameConfig.creditsPerKill;
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
    for (final entry in remoteShips.entries.toList()) {
      if (now.difference(entry.value.lastSeen) > GameConfig.silentTankTimeout) {
        _handleRemoteDeath(entry.key, explode: false);
      }
    }
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
    activeRound.fallen.add(bot.playerId);
    aliveCount.value = activeRound.alive.length;
    world.add(Explosion(position: bot.position.clone(), color: bot.shipColor));
    shakeAt(bot.position, 8);
    // Waves leave far too many wrecks, only the explosion stays.
    if (!activeRound.isEnemy(bot.playerId)) {
      _addWreck(bot);
    }
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
    if (activeRound.isEnemy(id)) {
      activeRound.fallen.add(id);
    }
    aliveCount.value = activeRound.alive.length;
    final ship = remoteShips.remove(id);
    if (ship != null) {
      if (explode) {
        world.add(
          Explosion(position: ship.position.clone(), color: ship.shipColor),
        );
        shakeAt(ship.position, 8);
        if (!activeRound.isEnemy(id)) {
          _addWreck(ship);
        }
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
    if (activeRound.defense) {
      // Only the base decides a defense round, see [_applyDefense].
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
    winnerName.value = won ? 'Stützpunkt' : null;
    if (activeRound.participants.contains(myId)) {
      unawaited(
        scoreService.recordRound(name: myName, stats: roundStats, won: won),
      );
      outcome.value = won ? RoundOutcome.won : RoundOutcome.lost;
      AudioService.play(won ? 'win' : 'lose');
    }
    final base = _defenseField?.headquarters;
    if (base != null) {
      if (won) {
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

  void backToLobby() {
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

  /// Closes the waiting room: as host for everybody, as guest just for you.
  Future<void> closeRoom() async {
    if (phase.value == GamePhase.closed) {
      return;
    }
    final host = isHost.value;
    _enterClosed(
      host
          ? 'Du hast den Warteraum geschlossen.'
          : 'Du hast den Warteraum verlassen.',
    );
    await (host ? net.closeRoom() : net.dispose());
  }

  void _onClose(String id) {
    final sender = _rosterMember(id);
    if (sender == null || !sender.host || phase.value == GamePhase.closed) {
      return;
    }
    _enterClosed('Der Gastgeber hat den Warteraum geschlossen.');
    unawaited(net.dispose());
  }

  /// Nobody started a round or came and went for a long time: leave the
  /// room, so forgotten tabs do not keep it open forever.
  void _closeWhenIdle() {
    if (phase.value != GamePhase.lobby) {
      return;
    }
    final idle = DateTime.now().difference(_lastActivity);
    if (idle < GameConfig.lobbyIdleTimeout) {
      return;
    }
    _enterClosed(
      'Der Warteraum wurde nach '
      '${GameConfig.lobbyIdleTimeout.inMinutes} Minuten ohne Aktivität '
      'geschlossen.',
    );
    unawaited(net.dispose());
  }

  void _enterClosed(String reason) {
    _clearWorld();
    round = null;
    myTeam = 0;
    roster.value = const [];
    closedReason.value = reason;
    _setPhase(GamePhase.closed);
  }

  /// Leaves the closed screen for a new room, hosted by this player.
  Future<void> openNewRoom() async {
    if (phase.value != GamePhase.closed || openFreshRoom()) {
      return;
    }
    // No address bar to start over from: meet in the same room again.
    _setHost(true);
    _lastActivity = DateTime.now();
    closedReason.value = null;
    _setPhase(GamePhase.lobby);
    await net.connect(_presencePayload());
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
    final before = {for (final member in roster.value) member.id};
    final after = {for (final member in members) member.id};
    if (before.length != after.length || !before.containsAll(after)) {
      _lastActivity = DateTime.now();
    }
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
    _defenseField?.removeFromParent();
    _defenseField = null;
    defenseMap = null;
    defense.value = null;
    for (final tower in towers.values) {
      tower.removeFromParent();
    }
    towers.clear();
    credits.value = 0;
    _respawnTimer = 0;
    respawnSeconds.value = 0;
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
    drones.clear();
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

enum RoundOutcome { none, won, lost }
