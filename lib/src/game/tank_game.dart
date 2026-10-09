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
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../app/overlay_ids.dart';
import '../audio/audio_service.dart';
import '../db/account_service.dart';
import '../db/profile_service.dart';
import '../db/room_slots.dart';

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
import '../net/payloads/flag_payload.dart';
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
import '../net/retry_backoff.dart';
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
import 'components/flag_field.dart';
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
import 'flag_match.dart';
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

part 'tank_game/lobby.dart';
part 'tank_game/round.dart';
part 'tank_game/replay.dart';
part 'tank_game/defense.dart';
part 'tank_game/air.dart';
part 'tank_game/infantry.dart';
part 'tank_game/items.dart';
part 'tank_game/combat.dart';
part 'tank_game/targeting.dart';
part 'tank_game/view.dart';
part 'tank_game/flag.dart';

/// Whether the welcome page comes before the start page. Everybody else
/// lands right on the three ways to play and signs in from the account
/// button there; only a mail link that failed to sign in here needs the
/// page, to explain why and to take the code instead.
bool needsWelcome({
  required bool accounts,
  required bool guest,
  bool mailLinkFailed = false,
}) => accounts && guest && mailLinkFailed;

class TankGame extends FlameGame
    with HasKeyboardHandlerComponents, HasCollisionDetection {
  TankGame({
    required this.net,
    required this.myId,
    required this.scoreService,
    required this.profiles,
    required this.accounts,
    this._directory,
    this._slots,
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

  /// The next defense round is a duel: two players, a base each at either
  /// end of the road, each side's waves against the other.
  final duelNext = ValueNotifier<bool>(false);

  /// Troops this player sent in a defense duel, for their ids.
  int _troopCounter = 0;

  /// A defense duel of two players on this screen: the whole field at once,
  /// from above, with both players' tanks on it, instead of a camera behind
  /// the own tank.
  final overview = ValueNotifier<bool>(false);

  /// The second player's game on this screen, while there is one.
  TankGame? partner;

  /// A second player on the same Apple TV joined this room with a game of
  /// their own: single player rounds take them along.
  bool localGuest = false;

  /// Which controller of the Apple TV steers here: the first, in a duel
  /// the one of the half, -1 for none when a phone steers the half.
  int tvPlayer = onTv ? 0 : -1;

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

  /// Whether the player got past the welcome page, see [needsWelcome].
  late final welcomed = ValueNotifier<bool>(
    !needsWelcome(
      accounts: Env.accounts,
      guest: accounts.isGuest,
      mailLinkFailed: AccountService.mailLinkFailed,
    ),
  );

  /// Whether the host still looks at the start page with the three ways to
  /// play. Players who joined by a link go straight to the waiting room.
  late final choosingMode = ValueNotifier<bool>(net.isHost);

  /// Whether the host looks at the settings of the round, opened from the
  /// waiting room. Rounds start with the defaults until then.
  final configuring = ValueNotifier<bool>(false);

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

  /// Capture the flag: where both flags are and the score, null in any
  /// other round. The authority's last full state goes out again every few
  /// seconds.
  FlagMatch? flagMatch;
  double _flagSync = 0;
  bool _flagOvertime = false;

  /// Host: CPU tanks of a capture the flag round waiting to come back, with
  /// the seconds left.
  final _botRespawns = <String, double>{};

  /// Whether the host lists this room publicly. Private rooms are only
  /// reachable by their link or code.
  final publicRoom = ValueNotifier<bool>(false);

  /// Records the current round, and the last one to watch again.
  final _recorder = ReplayRecorder();
  final lastReplay = ValueNotifier<Replay?>(null);
  final replaying = ValueNotifier<bool>(false);
  ReplayPlayer? _replayPlayer;

  /// The public list of rooms.
  late final directory = _directory ?? RoomDirectory(room: net.room);
  final RoomDirectory? _directory;

  /// The project-wide slots for rooms with more than one pilot.
  late final slots = _slots ?? RoomSlots(Supabase.instance.client);
  final RoomSlots? _slots;
  async.Timer? _slotTimer;
  var _slotHeld = false;
  int? _claimedLoad;

  /// Team wanted in the lobby (0 for any) and the one given for the round.
  int teamPick = 0;
  int myTeam = 0;

  /// How well CPU tanks fight, and whether they fill up a room with few
  /// people.
  final botLevel = ValueNotifier<BotLevel>(BotLevel.normal);
  final fillWithBots = ValueNotifier<bool>(false);

  /// Whether a paired phone steers this game's tank. Set by `PadScreen`.
  final padSteered = ValueNotifier<bool>(false);

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
      ..onTankStates = _onTankStates
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
      ..onTroops = _onTroops
      ..onFlag = _onFlag
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
    padSteered.addListener(_onPadSteered);
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

  /// Host: the latest state of every CPU tank, sent together.
  final _botStates = <String, TankStatePayload>{};
  double _sinceBotStates = 0;

  /// A CPU tank of this host has a new state to tell the others.
  void queueBotState(TankStatePayload state) => _botStates[state.id] = state;

  void _sendBotStates(double dt) {
    _sinceBotStates += dt;
    if (_sinceBotStates < GameConfig.stateSyncInterval || _botStates.isEmpty) {
      return;
    }
    _sinceBotStates = 0;
    final states = _botStates.values.toList();
    _botStates.clear();
    for (var i = 0; i < states.length; i += TankStatesPayload.maxStates) {
      net.send(
        NetEvent.states,
        TankStatesPayload(
          id: myId,
          states: states.sublist(
            i,
            min(states.length, i + TankStatesPayload.maxStates),
          ),
        ).toJson(),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _sendBotStates(dt);
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
    _updateFlag(dt);
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

  static final _liveMatchPhases = {
    GamePhase.countdown.name,
    GamePhase.playing.name,
  };

  static double _headingFrom(Vector2 from, Vector2 to) =>
      atan2(to.x - from.x, -(to.y - from.y));

  double _resupplied = 0;

  static const _defenseMargin = 60.0;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _fitCamera();
  }

  /// Left the room quietly after a long time on the start or welcome page.
  @visibleForTesting
  var dozing = false;
}

enum RoundOutcome { none, won, lost }
