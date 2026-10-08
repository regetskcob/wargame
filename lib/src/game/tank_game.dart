import 'dart:async';
import 'dart:async' as async;
import 'dart:math';
import 'dart:ui' show Canvas, Color, Gradient, Offset, Paint, Rect, Size;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart' show Rectangle;
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../app/overlay_ids.dart';
import '../audio/audio_service.dart';
import '../db/account_service.dart';
import '../db/profile_service.dart';
import '../db/score_service.dart';
import '../app/env.dart';
import '../haptics.dart';
import '../tv/tv_input.dart';
import '../watch/watch_support.dart';
import 'game_config.dart';
import '../net/net_events.dart';
import '../net/net_service.dart';
import '../net/payloads/death_payload.dart';
import '../net/payloads/defense_payload.dart';
import '../net/payloads/hit_payload.dart';
import '../net/payloads/lobby_presence.dart';
import '../net/payloads/obstacle_payload.dart';
import '../net/payloads/soldier_payload.dart';
import '../net/payloads/special_payload.dart';
import '../net/payloads/power_up_payload.dart';
import '../net/payloads/round_start_payload.dart';
import '../net/payloads/tank_state_payload.dart';
import '../net/payloads/shoot_payload.dart';
import '../net/payloads/strike_payload.dart';
import '../net/replay.dart';
import '../net/room_directory.dart';
import '../net/room.dart';
import 'components/aim_overlay.dart';
import 'components/artillery_strike.dart';
import 'components/tree.dart';
import 'components/mine.dart';
import 'components/cover_field.dart';
import 'components/drone.dart';
import 'components/grenade.dart';
import 'components/effects.dart';
import 'components/mud_field.dart';
import 'components/obstacle.dart';
import 'map_theme.dart';
import 'pilot_progress.dart';
import 'weather.dart';
import 'plausibility.dart';
import 'components/bullet.dart';
import 'components/explosion.dart';
import 'components/player_tank.dart';
import 'components/power_up.dart';
import 'components/smoke_cloud.dart';
import 'components/remote_tank.dart';
import 'components/ground.dart';
import 'components/storm_zone.dart';
import 'defense/aircraft.dart';
import 'defense/ally_brain.dart';
import 'defense/defense_brain.dart';
import 'defense/defense_director.dart';
import 'defense/defense_field.dart';
import 'defense/defense_map.dart';
import 'defense/tower.dart';
import 'game_mode.dart';
import 'infantry.dart';
import 'inventory.dart';
import 'game_phase.dart';
import 'bot_brain.dart';
import 'bot_level.dart';
import 'components/soldier.dart';
import 'kill_feed.dart';
import 'components/tank_base.dart';
import 'components/tank_painter.dart';
import 'components/wreck.dart';
import 'round_stats.dart';
import 'special_weapon.dart';
import 'tank_stats.dart';
import 'terrain.dart';
import 'touch_input.dart';
import 'upgrades.dart';
import 'round_state.dart';
import '../l10n/l10n.dart';

/// Whether the welcome page asks how to play: accounts are switched on,
/// nobody is signed in, and this device did not choose the guest before,
/// or a mail link failed to sign in here.
bool needsWelcome({
  required bool accounts,
  required bool guest,
  required bool prefersGuest,
  bool mailLinkFailed = false,
}) => accounts && guest && (!prefersGuest || mailLinkFailed);

class TankGame extends FlameGame
    with HasKeyboardHandlerComponents, HasCollisionDetection {
  TankGame({
    required this.net,
    required this.myId,
    required this.scoreService,
    required this.profiles,
    required this.accounts,
  }) : super(camera: CameraComponent()) {
    welcomed.addListener(_wake);
    choosingMode.addListener(_wake);
  }

  final NetService net;
  final String myId;
  final ScoreService scoreService;
  final ProfileService profiles;
  final AccountService accounts;

  /// Bumped whenever name and look were loaded anew, after signing in.
  final pilotVersion = ValueNotifier<int>(0);
  String? _accountId;

  /// Rank, rating and badges of the local pilot.
  late final progress = PilotProgress(scores: scoreService, profiles: profiles);

  /// Account ids of the players in the current round, for the rating.
  final _uids = <String, String>{};

  /// What an account id looks like. Anything else in a presence would make
  /// the database refuse the whole round for the player who records it.
  static final _accountIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  async.Timer? _saveTimer;

  final phase = ValueNotifier<GamePhase>(GamePhase.lobby);
  final roster = ValueNotifier<List<LobbyPresence>>([]);
  late final hpNotifier = ValueNotifier<double>(myMaxHp);
  final aliveCount = ValueNotifier<int>(0);

  /// On-screen controls: shown on phones and tablets, or after the first touch.
  /// The Apple TV counts as iOS but has no touch screen.
  final touchMode = ValueNotifier<bool>(
    !onTv &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android),
  );
  final touch = TouchInput();
  late final _watchSteering = WatchSteering(touch);
  late final _tvSteering = TvSteering(this);

  /// Mouse position in widget pixels, null until a mouse is seen. The turret
  /// follows it.
  Vector2? pointer;

  /// The mouse is over a HUD button, so a click there does not fire.
  bool pointerOnHud = false;

  TrackLayer? _tracks;

  /// How the local player came out of the last round, for the end screens.
  final outcome = ValueNotifier<RoundOutcome>(RoundOutcome.none);
  final _extras = <Component>[];

  /// Seconds of rapid fire left, and the last crate the player picked up.
  final rapidFireSeconds = ValueNotifier<int>(0);
  final shieldSeconds = ValueNotifier<int>(0);
  final notice = ValueNotifier<String?>(null);
  async.Timer? _noticeTimer;

  /// Rounds left in the local tank's magazine.
  late final ammoNotifier = ValueNotifier<int>(myMagazine);

  /// Special weapon of the local tank and its charges, null without one.
  final specialNotifier = ValueNotifier<(SpecialWeapon, int)?>(null);

  /// Drones in the air, the local ones and those of other players.
  final drones = <String, Drone>{};

  /// Enemy helicopters and jets of a defense round.
  final aircraft = <String, Aircraft>{};

  /// What the local player picked up and can set off later.
  final inventory = Inventory();

  /// Upgrades of the local tank in a defense round, by their level.
  final upgrades = ValueNotifier<Map<UpgradeKind, int>>(const {});

  /// Which gun B puts down, and the player's own gun right next to the tank,
  /// which B upgrades instead.
  final towerChoice = ValueNotifier<TowerKind>(TowerKind.cannon);
  final nearTower = ValueNotifier<Tower?>(null);

  final random = Random();
  int _squadCounter = 0;

  /// Hills of the current round, flat on the easy level.
  Terrain terrain = Terrain.flat;
  TerrainLayer? _terrainLayer;

  /// Share of fuel left in the local tank.
  final fuelNotifier = ValueNotifier<double>(1);

  /// The level of the round: CPU tanks fight better, and from the middle
  /// level on fuel and shells run out and the land gets hilly.
  BotLevel get difficulty => round?.botLevel ?? botLevel.value;

  bool get usesFuel => difficulty != BotLevel.easy;
  bool get endlessAmmo => difficulty == BotLevel.easy;

  /// Blasts already applied, since a drone's blast also arrives by message.
  final _blasts = <String>{};

  List<PowerUpSlot> _powerUpSlots = const [];
  final powerUps = <int, PowerUp>{};
  final _gone = <int>{};
  final smokes = <SmokeCloud>[];
  final mines = <String, Mine>{};
  int _specialCounter = 0;
  final winnerName = ValueNotifier<String?>(null);
  RoundStats roundStats = RoundStats();
  final killFeed = ValueNotifier<List<KillEntry>>(const []);

  /// Computer controlled tanks this client simulates.
  final botTanks = <String, PlayerTank>{};

  /// Alone against CPU tanks, against other people, or together against
  /// waves. Only the host can change it, everybody who joins plays along.
  final mode = ValueNotifier<GameMode>(GameMode.multi);

  void setMode(GameMode value) => mode.value = value;

  /// Whether the player got past the welcome page by signing in or by
  /// choosing to play as a guest. Without accounts there is nothing to pick,
  /// and a browser that chose the guest once is not asked again.
  late final welcomed = ValueNotifier<bool>(
    !needsWelcome(
      accounts: Env.accounts,
      guest: accounts.isGuest,
      prefersGuest: prefersGuest(),
      mailLinkFailed: AccountService.mailLinkFailed,
    ),
  );

  /// Welcome page: go on without an account.
  void playAsGuest() {
    rememberGuest();
    welcomed.value = true;
  }

  /// Whether the host still looks at the start page with the three ways to
  /// play. Players who joined by a link go straight to the waiting room.
  late final choosingMode = ValueNotifier<bool>(net.isHost);

  /// Whether the host looks at the settings of the round, opened from the
  /// waiting room. Rounds start with the defaults until then.
  final configuring = ValueNotifier<bool>(false);

  /// Start page: take [value] and move on to the waiting room.
  void chooseMode(GameMode value) {
    mode.value = value;
    configuring.value = false;
    choosingMode.value = false;
  }

  /// Back to the start page, to play another way.
  void changeMode() => choosingMode.value = true;

  /// From the waiting room to the settings of the round.
  void editSettings() => configuring.value = true;

  /// The settings are done: back to the waiting room.
  void closeSettings() => configuring.value = false;

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

  /// Whether the host lists this room publicly. Private rooms are only
  /// reachable by their link or code.
  final publicRoom = ValueNotifier<bool>(false);

  /// Records the current round, and the last one to watch again.
  final _recorder = ReplayRecorder();
  final lastReplay = ValueNotifier<Replay?>(null);
  final replaying = ValueNotifier<bool>(false);
  ReplayPlayer? _replayPlayer;

  /// The public list of rooms.
  late final directory = RoomDirectory(room: net.room);

  void _updateListing() {
    final listed =
        isHost.value &&
        !beforeWaitingRoom &&
        mode.value == GameMode.multi &&
        publicRoom.value;
    final current = phase.value;
    unawaited(
      directory.advertise(
        listed
            ? RoomListing(
                room: net.room,
                host: myName,
                players: max(1, roster.value.length),
                inMatch:
                    current != GamePhase.lobby &&
                    current != GamePhase.roundOver,
                teams: teamMode.value,
              )
            : null,
      ),
    );
  }

  /// Team wanted in the lobby (0 for any) and the one given for the round.
  int teamPick = 0;
  int myTeam = 0;

  /// How well CPU tanks fight, and whether they fill up a room with few
  /// people.
  final botLevel = ValueNotifier<BotLevel>(BotLevel.normal);
  final fillWithBots = ValueNotifier<bool>(false);

  /// Whether the next round starts with red against blue.
  final teamMode = ValueNotifier<bool>(false);
  final spectatingName = ValueNotifier<String?>(null);

  String myName = 'Panzer-${1000 + Random().nextInt(9000)}';
  int myColorIndex = GameConfig.randomStarterStyle(Random());

  RoundState? round;

  /// Throws out what other players broadcast if their tank cannot do it.
  late final guard = PlausibilityGuard(statsOf: _statsOf);

  TankStats get myStats => TankStats.of(GameConfig.typeOf(myColorIndex));

  /// Rounds in a full magazine of the local tank, upgrades included.
  int get myMagazine =>
      (myStats.ammo *
              UpgradeKind.magazine.factorAt(_level(UpgradeKind.magazine)))
          .round();

  int _level(UpgradeKind kind) => upgrades.value[kind] ?? 0;
  double get myMaxHp => myStats.maxHp;

  TankStats _statsOf(String playerId) {
    return TankStats.of(GameConfig.typeOf(_styleFor(playerId)));
  }

  /// Distance from the middle of the screen, to fade out far away sounds.
  double _distanceToView(Vector2 point) =>
      point.distanceTo(camera.viewfinder.position);
  PlayerTank? myTank;
  final remoteTanks = <String, RemoteTank>{};
  final bullets = <String, Bullet>{};

  CoverField? _coverField;
  SoldierField? soldierField;

  /// Soldiers this player has run over in the current round.
  final soldiersRunOver = ValueNotifier<int>(0);
  Ground? _ground;
  MudField? mudField;

  /// Map picked in the lobby, null for a random one.
  final mapChoice = ValueNotifier<int?>(null);

  /// Weather and time of day of the current round.
  Conditions? conditions;
  final conditionsLabel = ValueNotifier<String?>(null);
  WeatherLayer? _weather;

  /// The weather that is giving way, faded out over a few seconds.
  WeatherLayer? _passingWeather;
  double _weatherCheck = 0;
  static const _weatherFade = 5.0;
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
    Haptics.shake(strength);
  }

  /// Shakes by [strength], weaker the further [at] is from the middle of the
  /// screen, so far away explosions barely register.
  void shakeAt(Vector2 at, double strength) {
    final distance = _distanceToView(at);
    shake(strength * (1 - (distance / 700).clamp(0.0, 1.0)));
  }

  /// Leaves a scorched hole in the ground until the round ends.
  void addCrater(Vector2 at, double radius) => _tracks?.addCrater(at, radius);

  /// A tank at [at] took [amount] damage from a shell. [mine] marks hits the
  /// local player dealt or took.
  void showHit(Vector2 at, double amount, {required bool mine, Color? color}) {
    world.add(
      DamageNumber(
        position: at + Vector2(0, -GameConfig.tankRadius),
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

  /// Draws one weather layer. render() calls this per layer instead of
  /// looping over [?_passingWeather, ?_weather]: that list crashed the
  /// Android release build with SIGSEGV on the first frame of a round,
  /// while debug builds ran fine.
  void _renderWeather(
    Canvas canvas,
    WeatherLayer layer,
    bool playing,
    PlayerTank? tank,
  ) {
    layer.render(
      canvas,
      Size(canvasSize.x, canvasSize.y),
      camera: camera.viewfinder.position.toOffset(),
      scale: viewScale,
      heading: playing ? tank!.angle : null,
      focus: playing
          ? ((tank!.position - camera.viewfinder.position) * viewScale +
                    canvasSize / 2)
                .toOffset()
          : null,
      // Spectators and the fallen see the whole field.
      veil: playing,
    );
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
    final tank = myTank;
    final playing =
        (phase.value == GamePhase.playing ||
            phase.value == GamePhase.countdown) &&
        tank != null;
    final passing = _passingWeather;
    if (passing != null) _renderWeather(canvas, passing, playing, tank);
    final weather = _weather;
    if (weather != null) _renderWeather(canvas, weather, playing, tank);
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
    world
      ..add(AimOverlay())
      ..add(InfantryCommand());
    net
      ..onTankState = _onTankState
      ..onShoot = _onShoot
      ..onHit = _onHit
      ..onDeath = _onDeath
      ..onPickup = _onPickup
      ..onSmoke = _onSmoke
      ..onObstacle = _onObstacle
      ..onSoldier = _onSoldier
      ..onMine = _onMine
      ..onArtillery = _onArtillery
      ..onDefense = _onDefense
      ..onTower = _onTower
      ..onGrenade = _onGrenade
      ..onDrone = _onDrone
      ..onBlast = _onBlast
      ..onAir = _onAir
      ..onSquad = _onSquad
      ..onUse = _onUse
      ..onRoundStart = _onRoundStart
      ..onRosterChanged = _onRosterChanged
      ..onPeerLeft = _onPeerLeft
      ..onClose = _onClose;
    _accountId = scoreService.myId;
    await _loadPilot();
    accounts.user.addListener(_onAccountChanged);
    _adoptLanguage();
    L10n.lang.addListener(_saveLanguage);
    net.recorder = _recorder;
    await net.connect(_presencePayload());
    directory.connect();
    for (final notifier in <Listenable>[
      publicRoom,
      choosingMode,
      welcomed,
      mode,
      isHost,
      teamMode,
      phase,
      roster,
    ]) {
      notifier.addListener(_updateListing);
    }
    overlays.add(OverlayIds.lobby);
    _refreshTutorialDone();
    touchMode.addListener(_refreshTutorialDone);
  }

  /// Whether the player went through the tutorial for the current
  /// controls. It never opens by itself, the buttons that open it stand out
  /// until then.
  final tutorialDone = ValueNotifier<bool>(true);

  void _refreshTutorialDone() => tutorialDone.value = _tutorialSeen();

  /// Seen in this browser, or on the account for the current controls. A
  /// browser that saw it before accounts kept the marker hands it on.
  bool _tutorialSeen() {
    if (tutorialSeen()) {
      unawaited(accounts.rememberTutorialSeen(touch: touchMode.value));
      return true;
    }
    if (accounts.olderThanTutorial) {
      // Players from before the tutorial get the marker right away, for
      // both kinds of controls.
      rememberTutorialSeen();
      unawaited(() async {
        await accounts.rememberTutorialSeen(touch: true);
        await accounts.rememberTutorialSeen(touch: false);
      }());
      return true;
    }
    return accounts.tutorialSeen(touch: touchMode.value);
  }

  /// Opens the tutorial over everything else, from the welcome page, the
  /// start page or the waiting room.
  void showTutorial() {
    if (!overlays.isActive(OverlayIds.tutorial)) {
      overlays.add(OverlayIds.tutorial);
    }
  }

  /// Closes the tutorial and marks it as seen, whether it was finished or
  /// skipped.
  void closeTutorial() {
    rememberTutorialSeen();
    tutorialDone.value = true;
    unawaited(accounts.rememberTutorialSeen(touch: touchMode.value));
    overlays.remove(OverlayIds.tutorial);
  }

  /// Escape leaves a replay.
  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        replaying.value) {
      stopReplay();
      return KeyEventResult.handled;
    }
    // The Apple TV sends swipes and clicks as arrows and enter as well.
    // While the tank drives they must not walk the focus off to the HUD
    // and press its buttons.
    if (onTv &&
        (phase.value == GamePhase.countdown ||
            phase.value == GamePhase.playing)) {
      return KeyEventResult.handled;
    }
    return super.onKeyEvent(event, keysPressed);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _shake = max(0, _shake - dt * 28);
    _weather?.update(dt);
    _turnWeather(dt);
    _damageFlash = max(0, _damageFlash - dt * 2.5);
    final activeRound = round;
    if (phase.value == GamePhase.countdown && activeRound != null) {
      final remainingMs =
          activeRound.startedAt - DateTime.now().millisecondsSinceEpoch;
      final seconds = (remainingMs / 1000).ceil();
      if (seconds > 0 && seconds != _lastTick) {
        _lastTick = seconds;
        AudioService.play('tick');
        Haptics.tick();
      }
      if (remainingMs <= 0) {
        _lastTick = -1;
        _setPhase(GamePhase.playing);
        AudioService.play('go');
        Haptics.go();
      }
    }
    _watchSteering.update(
      playing: phase.value == GamePhase.playing,
      tank: myTank,
      tankAngle: myTank?.angle ?? 0,
      hard: difficulty == BotLevel.hard,
    );
    _tvSteering.update();
    _playReplay();
    _updatePowerUps();
    _updateRespawn(dt);
    _resupply(dt);
    _staleTimer += dt;
    if (_staleTimer >= 1) {
      _settleHost(_staleTimer);
      _staleTimer = 0;
      _dropSilentTanks();
      closeWhenIdle();
    }
    _engineTimer += dt;
    if (_engineTimer >= 0.1) {
      _engineTimer = 0;
      final tank = myTank;
      if (phase.value == GamePhase.playing && tank != null) {
        unawaited(AudioService.engine(tank.load.abs()));
      } else {
        unawaited(AudioService.stopEngine());
      }
    }
  }

  /// Signing in or out swaps the account: bring in its name, look and
  /// progress.
  void _onAccountChanged() {
    if (!accounts.isGuest) {
      welcomed.value = true;
    }
    _refreshTutorialDone();
    final id = accounts.user.value?.id;
    if (id == null || id == _accountId) {
      return;
    }
    _accountId = id;
    _adoptLanguage();
    unawaited(() async {
      await _loadPilot();
      pilotVersion.value++;
      await pushPresence();
    }());
  }

  /// Speaks the language kept with the account. An account without one
  /// takes the language in use on this device.
  void _adoptLanguage() {
    final kept = accounts.language;
    if (kept == null) {
      _saveLanguage();
    } else if (kept != L10n.current) {
      unawaited(L10n.set(kept));
    }
  }

  void _saveLanguage() => unawaited(accounts.rememberLanguage(L10n.current));

  /// Name, look and progress from the last visit. Gives up after a few
  /// seconds so a slow network never holds up the lobby.
  Future<void> _loadPilot() async {
    try {
      final profile = await profiles.load().timeout(const Duration(seconds: 3));
      await progress.load().timeout(const Duration(seconds: 3));
      if (profile != null) {
        myName = profile.name;
        final color = profile.style % GameConfig.tankColors.length;
        final type = GameConfig.typeOf(profile.style);
        myColorIndex = GameConfig.styleOf(
          progress.vehicleUnlocked(type) ? type.index : TankType.puma.index,
          progress.unlocked(color) ? color : 0,
        );
      } else if (accounts.user.value?.userMetadata['call_sign']
          case final String name when name.isNotEmpty) {
        // Registered elsewhere, first time on this device.
        myName = name;
      }
    } on Object {
      return;
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
      uid: scoreService.myId,
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

  /// The call sign given when registering: shown everywhere instead of the
  /// e-mail address.
  void claimCallSign(String name) {
    setPilot(name: name, colorIndex: myColorIndex);
    pilotVersion.value++;
  }

  void setPilot({required String name, required int colorIndex}) {
    myName = name.trim().isEmpty ? myName : name.trim();
    final color = colorIndex % GameConfig.tankColors.length;
    if (progress.unlocked(color) &&
        progress.vehicleUnlocked(GameConfig.typeOf(colorIndex))) {
      myColorIndex = colorIndex;
    }
    unawaited(pushPresence());
    // Typing a name calls this on every key, so save once it settles.
    _saveTimer?.cancel();
    _saveTimer = async.Timer(const Duration(milliseconds: 800), () {
      unawaited(profiles.save(name: myName, style: myColorIndex));
    });
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
    _ground = Ground(theme, plain: plain);
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
      solo: solo,
      humans: ids.length,
      fill: fillWithBots.value && !defending,
      teams: teamMode.value,
      random: random,
    );
    final bots = <String, int>{
      for (var i = 1; i <= botCount; i++)
        'cpu-$i': GameConfig.randomStyle(random),
    };
    ids
      ..addAll(bots.keys)
      ..sort();
    final payload = RoundStartPayload(
      seed: switch (mapChoice.value) {
        final map? => MapTheme.seedFor(Random().nextInt(1 << 30), map),
        null => Random().nextInt(1 << 30),
      },
      startedAt:
          DateTime.now().millisecondsSinceEpoch +
          GameConfig.countdownSeconds * 1000,
      participants: ids,
      teams: defending ? const {} : _assignTeams(ids),
      bots: bots,
      botHost: bots.isEmpty && !defending ? null : myId,
      defense: defending,
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
                when _accountIdPattern.hasMatch(uid) &&
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
    _stormZone = StormZone(startedAt: payload.startedAt);
    _powerUpSlots = PowerUpSlot.schedule(payload.seed, activeRound.botLevel);
    world.add(_coverField!);
    _raiseTerrain(
      activeRound,
      _coverField!.theme,
      area: Rect.fromCircle(
        center: Offset.zero,
        radius: GameConfig.worldRadius,
      ),
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
    world.add(_stormZone!);
    mudField = MudField(seed: payload.seed, theme: _coverField!.theme);
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
      if (id == myId && !replay) {
        _spawnLocalTank(spawn, facing);
      } else if (!replay &&
          activeRound.isBot(id) &&
          activeRound.botHost == myId) {
        final controls = TouchInput();
        final tank = PlayerTank(
          playerId: id,
          playerName: name,
          tankColor: color,
          tankType: tankType,
          position: spawn,
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
        );
        _extras.add(brain);
        world.add(brain);
      } else {
        _addRemoteTank(id, spawn, facing);
      }
    }
    _enterRound(activeRound, payload: payload, replay: replay);
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

  /// Watches the round that just ended, or the last one recorded, again.
  void watchReplay() {
    final current = phase.value;
    if (current != GamePhase.lobby && current != GamePhase.roundOver) {
      return;
    }
    final recorded = _recorder.finish();
    if (recorded != null) {
      lastReplay.value = recorded;
    }
    final replay = lastReplay.value;
    if (replay == null) {
      return;
    }
    // A short moment to look around before the first shots.
    final startedAt = DateTime.now().millisecondsSinceEpoch + 1500;
    _replayPlayer = ReplayPlayer(replay, startedAt: startedAt);
    net.muted = true;
    replaying.value = true;
    final original = replay.round;
    _applyRoundStart(
      RoundStartPayload(
        seed: original.seed,
        startedAt: startedAt,
        participants: original.participants,
        teams: original.teams,
        bots: original.bots,
        botHost: original.botHost,
        botLevel: original.botLevel,
      ),
      replay: true,
    );
  }

  void stopReplay() {
    if (_replayPlayer == null) {
      return;
    }
    _replayPlayer = null;
    replaying.value = false;
    net.muted = false;
    _clearWorld();
    round = null;
    _setPhase(GamePhase.lobby);
    unawaited(pushPresence());
  }

  /// Feeds the recorded messages that are due into the game, as if they had
  /// just come over the network.
  void _playReplay() {
    final player = _replayPlayer;
    if (player == null) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final event in player.due(now).toList()) {
      final json = event.payload;
      switch (event.event) {
        case NetEvent.state:
          _onTankState(TankStatePayload.fromJson(json));
        case NetEvent.shoot:
          _onShoot(ShootPayload.fromJson(json));
        case NetEvent.hit:
          _onHit(HitPayload.fromJson(json));
        case NetEvent.death:
          _onDeath(DeathPayload.fromJson(json));
        case NetEvent.pickup:
          _onPickup(PickupPayload.fromJson(json));
        case NetEvent.smoke:
          _onSmoke(SmokePayload.fromJson(json));
        case NetEvent.obstacle:
          _onObstacle(ObstaclePayload.fromJson(json));
        case NetEvent.soldier:
          _onSoldier(SoldierPayload.fromJson(json));
        case NetEvent.mine:
          _onMine(MinePayload.fromJson(json));
        case NetEvent.artillery:
          final strike = ArtilleryPayload.fromJson(json);
          _onArtillery(
            ArtilleryPayload(
              id: strike.id,
              strikeId: strike.strikeId,
              x: strike.x,
              y: strike.y,
              at: strike.at + player.shift,
            ),
          );
        case NetEvent.grenade:
          _onGrenade(GrenadePayload.fromJson(json));
        case NetEvent.drone:
          _onDrone(DronePayload.fromJson(json));
        case NetEvent.blast:
          _onBlast(BlastPayload.fromJson(json));
        case NetEvent.squad:
          _onSquad(SquadPayload.fromJson(json));
        case NetEvent.use:
          _onUse(UsePayload.fromJson(json));
        case NetEvent.air ||
            NetEvent.roundStart ||
            NetEvent.defense ||
            NetEvent.tower ||
            NetEvent.close:
          break;
      }
    }
    if (player.done && now > player.startedAt + player.replay.length + 3000) {
      stopReplay();
    }
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
    camera.follow(tank, snap: true);
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

  /// The fixed map of a defense round: road, base and the players in front
  /// of it. The player who runs the enemies also gets the director.
  void _setUpDefense(RoundState activeRound) {
    final map = DefenseMap.forSeed(activeRound.seed);
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
      keepClear: [map.base],
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
      wave: 0,
      nextWaveAt: activeRound.startedAt + GameConfig.firstWaveSeconds * 1000,
    );
    final players = activeRound.participants;
    for (var i = 0; i < players.length; i++) {
      final id = players[i];
      final spawn = map.spawnFor(i, players.length);
      final facing = _headingFrom(spawn, map.road[map.road.length - 2]);
      if (id == myId) {
        _spawnLocalTank(spawn, facing);
      } else {
        _addRemoteTank(id, spawn, facing);
      }
    }
    if (activeRound.botHost == myId) {
      final director = DefenseDirector(
        startedAt: activeRound.startedAt,
        allies: max(1, GameConfig.defenseSquad - players.length),
      );
      _extras.add(director);
      world.add(director);
    }
    _enterRound(activeRound);
  }

  static double _headingFrom(Vector2 from, Vector2 to) =>
      atan2(to.x - from.x, -(to.y - from.y));

  /// Lets the weather turn and day and night take turns when the seed and
  /// the round clock say so, and fades the old sky out while the new one
  /// comes in.
  void _turnWeather(double dt) {
    final current = _weather;
    if (current != null && current.opacity < 1) {
      current.opacity = min(1, current.opacity + dt / _weatherFade);
    }
    final passing = _passingWeather;
    if (passing != null) {
      passing
        ..update(dt)
        ..opacity -= dt / _weatherFade;
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

  /// Host of a defense round: an enemy rolls in at the start of the road.
  void spawnEnemy(String id) {
    final activeRound = round;
    final map = defenseMap;
    if (activeRound == null || map == null) {
      return;
    }
    final style = activeRound.enemyStyle(id);
    final controls = TouchInput();
    final tank =
        PlayerTank(
            playerId: id,
            playerName: activeRound.botName(id),
            tankColor: GameConfig.colorOf(style),
            tankType: GameConfig.typeOf(style),
            position: map.entry.clone(),
            angle: _headingFrom(map.entry, map.road[1]),
            controls: controls,
          )
          ..team = 2
          ..endlessAmmo = true
          ..speedFactor = GameConfig.enemySpeed
          ..fireFactor = GameConfig.enemyFireFactor
          ..armorFactor = GameConfig.enemyArmorIn(defense.value?.wave ?? 0)
          ..syncInterval = GameConfig.enemySyncInterval;
    activeRound.alive.add(id);
    aliveCount.value = activeRound.alive.length;
    botTanks[id] = tank;
    world.add(tank);
    final brain = DefenseBrain(tank: tank, controls: controls, map: map);
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
            angle: _headingFrom(at, route.first),
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
  void spawnEnemySquad(String id, int wave) {
    final map = defenseMap;
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
      ),
      send: true,
    );
  }

  /// Host of a defense round: the base sends [count] squads on foot up the
  /// road against wave [wave], a few seconds apart. They hold a line and
  /// fight what comes.
  void spawnBaseSquads(int wave, int count) {
    final map = defenseMap;
    if (map == null) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < count; i++) {
      final id = 'ally-q$wave-$i';
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
        ),
        send: true,
      );
    }
    showNotice(tr('EIGENE INFANTERIE RÜCKT AUS', 'OWN INFANTRY MOVING OUT'));
  }

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
      angle: _headingFrom(from, goal),
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
        angle: _headingFrom(from, goal),
        goal: goal,
      );
    } else {
      // Lifts off from the base.
      final from = map.base + Vector2(0, -DefenseMap.baseRadius);
      plane = Aircraft(
        unitId: id,
        kind: kind,
        position: from,
        angle: _headingFrom(from, map.road[map.road.length - 2]),
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
      angle: _headingFrom(map.entry, map.base),
      life: GameConfig.enemyDroneSeconds,
    );
    drones[id] = drone;
    _extras.add(drone);
    world.add(drone);
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
      map: defenseMap,
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

  /// Host: an enemy made it to the base and blows itself up there.
  void raidBase(PlayerTank enemy) {
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
    base
      ?..hp = state.hp
      ..level = state.hq;
    defense.value = state;
    if (before != null && state.hq > before.hq) {
      showNotice(
        tr(
          'STÜTZPUNKT AUSGEBAUT: ${GameConfig.hqName(state.hq)}  '
              '+${GameConfig.hqTowerStep} GESCHÜTZE',
          'BASE UPGRADED: ${GameConfig.hqName(state.hq)}  '
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
      _endDefense(won: state.result == DefenseResult.won);
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
      GameConfig.hqTowerStep * ((defense.value?.hq ?? 1) - 1);

  /// Host: the base grew to [level] and gets guns of its own, a cannon on
  /// the barracks and flak on the fortress besides.
  void armBase(int level) {
    final map = defenseMap;
    if (map == null) {
      return;
    }
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
        id: myId,
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
    if (!(round?.isEnemy(ownerId) ?? false)) {
      return;
    }
    for (final tower in towers.values.toList()) {
      final distance = tower.position.distanceTo(at);
      if (distance <= radius + 26) {
        damageTower(tower, damage * (1 - 0.5 * (distance / (radius + 26))));
      }
    }
  }

  /// The closest gun or trench of the defenders within [range] of [from],
  /// for the enemy to shoot at when no tank is near.
  Tower? nearestTower(Vector2 from, double range) => _nearestOf(from, range, [
    for (final tower in towers.values)
      if (!tower.isHq && tower.hp > 0) tower,
  ]);

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
    switch (tower.kind) {
      case TowerKind.flak:
        return _nearestOf(at, range, [
              for (final plane in aircraft.values)
                if (plane.hp > 0 && !plane.friendly) plane,
              for (final drone in drones.values)
                if (round?.isEnemy(drone.ownerId) ?? false) drone,
            ]) ??
            nearestEnemy(at, range);
      case TowerKind.cannon:
        return nearestEnemy(at, range) ?? _nearestEnemySoldier(at, range);
      case TowerKind.rockets:
        return nearestEnemy(at, range) ??
            _nearestOf(at, range, [
              for (final plane in aircraft.values)
                if (plane.hp > 0 && !plane.friendly) plane,
              for (final drone in drones.values)
                if (round?.isEnemy(drone.ownerId) ?? false) drone,
            ]) ??
            _nearestEnemySoldier(at, range);
      case TowerKind.trench:
        return null;
      case TowerKind.mortar || TowerKind.howitzer:
        bool outside(PositionComponent c) =>
            c.position.distanceTo(at) >= tower.kind.minRange;
        final target = _nearestOf(at, range, [
          for (final tank in _allTanks)
            if (tank.team == 2 && tank.hp > 0 && outside(tank)) tank,
        ]);
        return target ??
            _nearestOf(at, range, [
              for (final soldier in _enemySoldiers)
                if (outside(soldier)) soldier,
            ]);
    }
  }

  /// Touch aim assist: what the turret of [tank] should go for. In a defense
  /// round the same as a comrade would, otherwise the nearest tank of
  /// another side the player can see.
  PositionComponent? assistTarget(PlayerTank tank) {
    const range = GameConfig.assistRange;
    if (round?.defense ?? false) {
      return allyTarget(tank, range);
    }
    return _nearestOf(tank.position, range, [
      for (final other in _allTanks)
        if (other != tank &&
            other.hp > 0 &&
            !sameTeam(tank.playerId, other.playerId) &&
            canSee(other.position))
          other,
    ]);
  }

  /// What a CPU comrade in [tank] fires at: a Gepard goes for aircraft and
  /// drones first, every comrade for tanks before soldiers.
  PositionComponent? allyTarget(PlayerTank tank, double range) {
    final at = tank.position;
    if (tank.tankType == TankType.gepard) {
      final air = _nearestOf(at, range, [
        for (final plane in aircraft.values)
          if (plane.hp > 0 && !plane.friendly) plane,
        for (final drone in drones.values)
          if (round?.isEnemy(drone.ownerId) ?? false) drone,
      ]);
      if (air != null) {
        return air;
      }
    }
    return nearestEnemy(at, range) ?? _nearestEnemySoldier(at, range);
  }

  Iterable<Soldier> get _enemySoldiers =>
      (soldierField?.all ?? const <Soldier>[]).where(
        (s) =>
            !s.dead &&
            s.isMounted &&
            !s.airborne &&
            (round?.isEnemy(s.ownerId ?? '') ?? false),
      );

  Soldier? _nearestEnemySoldier(Vector2 from, double range) =>
      _nearestOf(from, range, _enemySoldiers);

  T? _nearestOf<T extends PositionComponent>(
    Vector2 from,
    double range,
    Iterable<T> candidates,
  ) {
    T? best;
    var bestDistance = range;
    for (final candidate in candidates) {
      if (!candidate.isMounted) {
        continue;
      }
      final distance = candidate.position.distanceTo(from);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = candidate;
      }
    }
    return best;
  }

  Vector2 velocityOfTarget(PositionComponent target) => switch (target) {
    final TankBase tank => velocityOf(tank),
    final Aircraft plane => plane.velocity,
    final Drone drone => drone.velocity,
    _ => Vector2.zero(),
  };

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

  // Built without null-aware list elements: such a list literal crashed
  // the Android release build in render(), see _renderWeather.
  Iterable<TankBase> get _allTanks sync* {
    final tank = myTank;
    if (tank != null) yield tank;
    yield* remoteTanks.values;
    yield* botTanks.values;
  }

  TankBase? _nearest(Vector2 from, double range, bool Function(int) team) {
    TankBase? best;
    var bestDistance = range;
    for (final tank in _allTanks) {
      if (!tank.isMounted || tank.hp <= 0 || !team(tank.team)) {
        continue;
      }
      final distance = tank.position.distanceTo(from);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = tank;
      }
    }
    return best;
  }

  /// Closest enemy of a defense round within [range] of [from].
  TankBase? nearestEnemy(Vector2 from, double range) =>
      _nearest(from, range, (team) => team == 2);

  /// Closest player tank within [range] of [from], for the enemies to shoot.
  TankBase? nearestDefender(Vector2 from, double range) =>
      _nearest(from, range, (team) => team == 1);

  Vector2 velocityOf(TankBase tank) => switch (tank) {
    final PlayerTank local => local.velocity,
    final RemoteTank remote => remote.velocity,
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
    _spawnLocalTank(at, _headingFrom(at, map.road[map.road.length - 2]));
    activeRound.alive.add(myId);
    aliveCount.value = activeRound.alive.length;
    hpNotifier.value = myMaxHp;
    ammoNotifier.value = myMagazine;
    specialNotifier.value = null;
  }

  double _resupplied = 0;

  /// Defense round: the base is the ammo dump. A tank next to it gets its
  /// magazine refilled bit by bit, since no gems lie on this map.
  void _resupply(double dt) {
    final tank = myTank;
    final map = defenseMap;
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

  /// The tanks people drive: the local one and those of other players.
  Iterable<TankBase> get humanTanks sync* {
    final activeRound = round;
    final mine = myTank;
    if (mine != null && mine.isMounted && mine.hp > 0) {
      yield mine;
    }
    for (final tank in remoteTanks.values) {
      if (tank.hp > 0 && !(activeRound?.isBot(tank.playerId) ?? false)) {
        yield tank;
      }
    }
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
    if (runsShooter(strike.ownerId)) {
      final base = _defenseField?.headquarters;
      if (base != null &&
          (round?.isEnemy(strike.ownerId) ?? false) &&
          base.position.distanceTo(strike.position) <
              GameConfig.artilleryRadius + DefenseMap.baseRadius) {
        damageBase(strike.damage);
      }
      _blastTowers(
        strike.ownerId,
        strike.position,
        GameConfig.artilleryRadius,
        strike.damage,
      );
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
        antiAir: tank.tankType == TankType.gepard,
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

  /// Tanks [id] may shoot at: everybody alive outside its own team.
  Iterable<TankBase> enemiesOf(String id) sync* {
    final candidates = <TankBase?>[
      myTank,
      ...remoteTanks.values,
      ...botTanks.values,
    ];
    for (final tank in candidates) {
      if (tank != null &&
          tank.isMounted &&
          tank.hp > 0 &&
          tank.playerId != id &&
          !sameTeam(id, tank.playerId)) {
        yield tank;
      }
    }
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
    _blastTowers(ownerId, at, weapon.radius, weapon.damageAt(0) * power);
    _blastSoldiers(ownerId, at, weapon.radius);
  }

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
        damage: tower.kind.damage * tower.kind.damageFactor(tower.level),
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
      antiAir: owner?.tankType == TankType.gepard,
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
          activeRound.defense &&
          !activeRound.destroyedEnemies.contains(raw.id) &&
          (activeRound.isEnemy(raw.id) ||
              activeRound.isAlly(raw.id) ||
              activeRound.participants.contains(raw.id));
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
    if (round?.defense ?? false) {
      // Defenders come back after a short while, the round goes on.
      round?.alive.remove(myId);
      world.add(
        Explosion(position: tank.position.clone(), color: tank.tankColor),
      );
      shake(12);
      _addWreck(tank);
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

  /// Whether the local player can make out [point] through night, fog or
  /// sand. Without a tank of one's own everything is visible.
  bool canSee(Vector2 point) {
    final vision = conditions?.vision;
    final tank = myTank;
    if (vision == null || tank == null || phase.value != GamePhase.playing) {
      return true;
    }
    return tank.position.distanceTo(point) <= vision;
  }

  /// Pixels per world unit. The shorter side of the window always shows the
  /// same stretch of the world, the longer side simply shows more, so the map
  /// fills the whole window without black bars. A defense round looks from
  /// further up, to keep the road and the guns in view.
  ///
  /// The defense field is wider than tall. On an upright phone the short
  /// side alone would show the whole field small with empty space above and
  /// below, so there the field's height fills the screen instead and the
  /// camera follows the tank sideways.
  double get viewScale {
    final short = min(canvasSize.x, canvasSize.y);
    if (defenseMap == null) {
      return short / GameConfig.viewShortSide;
    }
    return max(
      short / GameConfig.defenseViewShortSide,
      canvasSize.y / (DefenseMap.halfHeight * 2 + _defenseMargin * 2),
    );
  }

  static const _defenseMargin = 60.0;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _fitCamera();
  }

  /// Zooms for the current round. In a defense round the camera also stays
  /// over the field, instead of showing the dark beyond the border when the
  /// player stands at the base near the edge.
  void _fitCamera() {
    final scale = viewScale;
    camera.viewfinder.zoom = scale;
    if (defenseMap == null || scale <= 0) {
      camera.setBounds(null);
      return;
    }
    const margin = _defenseMargin;
    final dx = max(
      1.0,
      DefenseMap.halfWidth + margin - canvasSize.x / 2 / scale,
    );
    final dy = max(
      1.0,
      DefenseMap.halfHeight + margin - canvasSize.y / 2 / scale,
    );
    camera.setBounds(Rectangle.fromLTRB(-dx, -dy, dx, dy));
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

  /// Whether a soldier of [owner] is on the side of [id]: its own soldiers,
  /// teammates and their soldiers. Bystanders have no side.
  bool allied(String? owner, String id) =>
      owner != null && (owner == id || sameTeam(owner, id));

  /// Whether [point] lies in a cloud of smoke.
  bool inSmoke(Vector2 point) => smokes.any((cloud) => cloud.covers(point));

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
    damageBase(GameConfig.soldierRaidDamage);
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

  void _onObstacle(ObstaclePayload payload) {
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

  int _styleFor(String id) {
    if (_replayPlayer?.replay.styles[id] case final style?) {
      return style;
    }
    if (id == myId) {
      return myColorIndex;
    }
    final activeRound = round;
    if (activeRound != null && activeRound.isEnemy(id)) {
      return activeRound.enemyStyle(id);
    }
    if (activeRound != null && activeRound.isAlly(id)) {
      return activeRound.allyStyle(id);
    }
    return activeRound?.bots[id] ?? _rosterMember(id)?.colorIndex ?? 0;
  }

  String _nameFor(String id) {
    if (_replayPlayer?.replay.names[id] case final name?) {
      return name;
    }
    if (id == myId) {
      return myName;
    }
    if (id.startsWith('inf-')) {
      final team = int.tryParse(id.substring(4)) ?? 0;
      return '${tr('INFANTERIE', 'INFANTRY')} ${GameConfig.teamNames[team.clamp(0, 2)]}'
          .trim();
    }
    final activeRound = round;
    if (activeRound != null && activeRound.isBot(id)) {
      return activeRound.botName(id);
    }
    return _rosterMember(id)?.name ?? tr('Panzer', 'Tank');
  }

  String _nameOf(String id) =>
      id == myId ? myName : remoteTanks[id]?.playerName ?? _nameFor(id);

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
      if (!replaying.value) {
        roundStats.kills++;
      }
      final PositionComponent? victim =
          remoteTanks[victimId] ?? botTanks[victimId] ?? aircraft[victimId];
      if (victim != null) {
        world.add(KillMarker(position: victim.position.clone()));
        shake(4);
      }
      if (activeRound.isEnemy(victimId)) {
        credits.value += aircraft.containsKey(victimId)
            ? GameConfig.creditsPerAircraft
            : GameConfig.creditsPerKill;
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
    activeRound.destroyedEnemies.add(bot.playerId);
    aliveCount.value = activeRound.alive.length;
    world.add(Explosion(position: bot.position.clone(), color: bot.tankColor));
    shakeAt(bot.position, 8);
    // Waves leave far too many wrecks, only the explosion stays.
    if (!activeRound.defense) {
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
      for (final botId in activeRound.bots.keys) {
        if (activeRound.alive.contains(botId)) {
          _handleRemoteDeath(botId, explode: false);
        }
      }
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
        if (!activeRound.isEnemy(id) && !activeRound.isAlly(id)) {
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
      outcome.value = won ? RoundOutcome.won : RoundOutcome.lost;
      AudioService.play(won ? 'win' : 'lose');
      Haptics.roundOver(won: won);
    }
    final base = _defenseField?.headquarters;
    if (base != null) {
      // An extended round is won even when the base falls at last.
      if (won && (defense.value?.hp ?? 1) > 0) {
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

  /// Host only: straight from the results into the next round, with the same
  /// settings and everybody who is still in the room.
  void rematch() {
    if (phase.value != GamePhase.roundOver || !canStart) {
      return;
    }
    backToLobby();
    startRound();
  }

  /// Closes the waiting room: as host for everybody, as guest just for you.
  Future<void> closeRoom() async {
    if (phase.value == GamePhase.closed) {
      return;
    }
    final host = isHost.value;
    _enterClosed(
      host
          ? tr(
              'Du hast den Warteraum geschlossen.',
              'You closed the waiting room.',
            )
          : tr(
              'Du hast den Warteraum verlassen.',
              'You left the waiting room.',
            ),
    );
    await (host ? net.closeRoom() : net.dispose());
  }

  void _onClose(String id) {
    final sender = _rosterMember(id);
    if (sender == null || !sender.host || phase.value == GamePhase.closed) {
      return;
    }
    // Anybody can claim to be host in their own presence. While the owner
    // is in the room only the owner closes it, and an id two presences
    // claim is somebody posing as another.
    final owners = roster.value.where((m) => m.owner).toList();
    if (net.duplicateIds.contains(id) ||
        owners.length > 1 ||
        (owners.length == 1 && owners.single.id != id)) {
      return;
    }
    _enterClosed(
      tr(
        'Der Gastgeber hat den Warteraum geschlossen.',
        'The host closed the waiting room.',
      ),
    );
    unawaited(net.dispose());
  }

  /// Nobody started a round or came and went for a long time: leave the
  /// room, so forgotten tabs do not keep it open forever.
  @visibleForTesting
  void closeWhenIdle({DateTime? now}) {
    if (phase.value != GamePhase.lobby || dozing) {
      return;
    }
    final idle = (now ?? DateTime.now()).difference(_lastActivity);
    if (idle < GameConfig.lobbyIdleTimeout) {
      return;
    }
    if (beforeWaitingRoom) {
      // No waiting room on screen to close: leave the room quietly and
      // join it again with the next step.
      dozing = true;
      roster.value = const [];
      unawaited(net.dispose());
      return;
    }
    _enterClosed(
      tr(
        'Der Warteraum wurde nach '
            '${GameConfig.lobbyIdleTimeout.inMinutes} Minuten ohne Aktivität '
            'geschlossen.',
        'The waiting room was closed after '
            '${GameConfig.lobbyIdleTimeout.inMinutes} minutes without '
            'activity.',
      ),
    );
    unawaited(net.dispose());
  }

  /// Whether the player still looks at the welcome page or, as host, at
  /// the start page: the room is joined, but no waiting room is shown.
  bool get beforeWaitingRoom =>
      !welcomed.value || (choosingMode.value && isHost.value);

  /// Left the room quietly after a long time on the start or welcome page.
  @visibleForTesting
  var dozing = false;

  /// Moving on to the waiting room joins the room again after dozing.
  void _wake() {
    if (!dozing || beforeWaitingRoom) {
      return;
    }
    dozing = false;
    _lastActivity = DateTime.now();
    unawaited(net.connect(_presencePayload()));
  }

  void _enterClosed(String reason) {
    _clearWorld();
    round = null;
    myTeam = 0;
    roster.value = const [];
    closedReason.value = reason;
    _setPhase(GamePhase.closed);
  }

  /// Leaves this room for good, before the apps swap in a game for another
  /// one: the channels close, timers stop and nothing writes anymore.
  Future<void> leave() async {
    if (_saveTimer?.isActive ?? false) {
      // A name typed just now still goes out.
      _saveTimer!.cancel();
      try {
        await profiles.save(name: myName, style: myColorIndex);
      } on Object {
        // Leaving the room matters more.
      }
    }
    _noticeTimer?.cancel();
    pauseEngine();
    L10n.lang.removeListener(_saveLanguage);
    accounts.dispose();
    await directory.dispose();
    await net.dispose();
  }

  /// Leaves the closed screen for the start page of a new room, hosted by
  /// this player.
  Future<void> backToStart() async {
    if (phase.value != GamePhase.closed || openFreshRoom()) {
      return;
    }
    // No address bar to start over from: meet in the same room again.
    _setHost(true);
    choosingMode.value = true;
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
    final targets = [...remoteTanks.values, ...botTanks.values];
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
