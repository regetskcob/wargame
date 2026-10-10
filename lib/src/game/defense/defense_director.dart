import 'package:flame/components.dart';

import '../../app/env.dart';
import '../game_config.dart';
import '../../net/payloads/defense_payload.dart';
import '../game_phase.dart';
import '../tank_game.dart';
import 'aircraft.dart';
import 'defense_map.dart';

/// Runs the waves of a defense round. Only the player who simulates the
/// enemies has one: it spawns them and the CPU comrades, keeps the score of
/// the base and tells the others how it stands.
class DefenseDirector extends Component with HasGameRef<TankGame> {
  DefenseDirector({required this.startedAt, required this.allies});

  final int startedAt;

  /// Number of CPU comrades on the side of the players at the start. Every
  /// step the base grows brings one more.
  final int allies;

  int get _allySlots => allies + (gameRef.defense.value?.hq ?? 1) - 1;

  /// Per comrade slot: the tank on the field, how often it was sent and the
  /// seconds until the next one rolls out of the base.
  late final _allyIds = List<String?>.filled(
    allies + GameConfig.hqCount - 1,
    null,
  );
  late final _allyLives = List<int>.filled(_allyIds.length, 0);
  late final _allyWait = List<double>.filled(_allyIds.length, 0);

  /// Per base: waves beaten off without heavy losses, and its hit points
  /// when the current wave rolled in.
  final _cleanWaves = [0, 0];
  final _hpAtWave = [GameConfig.baseHp, GameConfig.baseHp];

  /// A duel: every wave rolls down both roads, one to each player's base.
  bool get _duel => gameRef.round?.duel ?? false;

  List<int> get _lanes => _duel ? const [0, 1] : const [0];

  final _queue = <_Spawn>[];
  int _spawned = 0;

  /// Seconds until the base's jet takes off in this wave, null for none.
  double? _jetIn;
  double _spawnTimer = 0;
  double _keepalive = 0;

  int get _now => DateTime.now().millisecondsSinceEpoch;

  @override
  void onMount() {
    super.onMount();
    // The screenshot mode skips the first waves and opens with the base one
    // step grown, so aircraft and a fuller field show up at once.
    final staged = Env.shots && !_duel && Env.shotWave > 1;
    if (staged) {
      _cleanWaves[0] = GameConfig.hqCleanWaves[1];
      gameRef.armBase(2);
    }
    gameRef.publishDefense(
      DefensePayload(
        id: gameRef.myId,
        hp: GameConfig.baseHp + (staged ? GameConfig.hqHpStep : 0),
        hp2: _duel ? GameConfig.baseHp : null,
        wave: staged ? Env.shotWave - 1 : 0,
        hq: staged ? 2 : 1,
        nextWaveAt: startedAt + GameConfig.firstWaveSeconds * 1000,
      ),
    );
    for (var slot = 0; slot < allies; slot++) {
      _sendAlly(slot);
    }
  }

  /// A wave was beaten off. If the base held without heavy losses it may
  /// grow: more hit points, a fresh comrade and a gun of its own.
  DefensePayload _grow(DefensePayload state) {
    var next = state;
    for (final lane in _lanes) {
      final hq = next.hqOf(lane);
      final hp = next.hpOf(lane);
      final loss = _hpAtWave[lane] - hp;
      if (loss <= GameConfig.baseMaxHp(hq) * GameConfig.hqCleanLoss) {
        _cleanWaves[lane]++;
      }
      final level = GameConfig.hqLevelFor(_cleanWaves[lane]);
      if (level <= hq) {
        continue;
      }
      gameRef.armBase(level, lane: lane);
      next = next.withBase(
        lane,
        hq: level,
        hp: hp + GameConfig.hqHpStep * (level - hq),
      );
    }
    return next;
  }

  /// The defenders do not hold out on the ground alone for long: from a few
  /// waves in, the base sends aircraft of its own.
  void _sendSupport(int wave) {
    // In a duel the bases' aircraft would not know whose side to take.
    if (_duel) {
      return;
    }
    if (wave >= GameConfig.supportFromWave) {
      gameRef.spawnSupport('air-h-$wave', AirKind.helicopter);
    }
    _jetIn = wave >= GameConfig.supportJetFromWave
        ? GameConfig.supportJetDelay
        : null;
  }

  void _sendAlly(int slot) {
    final id = 'ally-$slot-${_allyLives[slot]++}';
    _allyIds[slot] = id;
    gameRef.spawnAlly(id, slot);
  }

  /// Sends a fresh comrade for every one that was destroyed, after a while.
  void _keepAllies(double dt) {
    for (var slot = 0; slot < _allySlots; slot++) {
      final id = _allyIds[slot];
      if (id != null && gameRef.botTanks.containsKey(id)) {
        continue;
      }
      if (id != null) {
        _allyIds[slot] = null;
        _allyWait[slot] = GameConfig.allyRespawnSeconds;
      }
      _allyWait[slot] -= dt;
      if (_allyWait[slot] <= 0) {
        _sendAlly(slot);
      }
    }
  }

  @override
  void update(double dt) {
    final phase = gameRef.phase.value;
    final state = gameRef.defense.value;
    if (state == null ||
        state.result != DefenseResult.running ||
        (phase != GamePhase.playing && phase != GamePhase.spectating)) {
      return;
    }
    _keepAllies(dt);
    var next = state;
    if (_duel) {
      final left = state.hpOf(0) <= 0;
      final right = state.hpOf(1) <= 0;
      if (left || right) {
        // Whose base falls first loses, both at once is a draw.
        gameRef.publishDefense(
          state.copyWith(
            result: DefenseResult.lost,
            fell: left && right ? 2 : (left ? 0 : 1),
          ),
        );
        return;
      }
    } else if (state.hp <= 0) {
      // Once extended the win is safe, however the base ends.
      gameRef.publishDefense(
        state.copyWith(
          hp: 0,
          result: state.extended ? DefenseResult.won : DefenseResult.lost,
        ),
      );
      return;
    }
    if (state.deciding && _now >= state.nextWaveAt) {
      // Nobody asked for more: the round ends with the regular waves.
      gameRef.publishDefense(state.copyWith(result: DefenseResult.won));
      return;
    }
    if (state.nextWaveAt > 0 && _now >= state.nextWaveAt) {
      next = state.copyWith(wave: state.wave + 1, nextWaveAt: 0);
      for (final lane in _lanes) {
        _hpAtWave[lane] = next.hpOf(lane);
      }
      _queue
        ..clear()
        ..addAll(_order(DefenseMap.planFor(next.wave)));
      _spawned = 0;
      _spawnTimer = 0;
      _sendSupport(next.wave);
      gameRef.digInEnemyGuns(next.wave);
      // Every base sends troops on foot against every wave, more as it
      // grows.
      for (final lane in _lanes) {
        gameRef.spawnBaseSquads(next.wave, next.hqOf(lane), lane: lane);
      }
    }
    final jetIn = _jetIn;
    if (jetIn != null) {
      _jetIn = jetIn - dt;
      if (_jetIn! <= 0) {
        _jetIn = null;
        gameRef.spawnSupport('air-j-${next.wave}', AirKind.jet);
      }
    }
    _spawnTimer -= dt;
    if (_queue.isNotEmpty && _spawnTimer <= 0) {
      final spawn = _queue.first;
      final room =
          spawn != _Spawn.tank ||
          gameRef.enemiesAlive < GameConfig.maxEnemiesAlive * _lanes.length;
      if (room) {
        _queue.removeAt(0);
        // The same wave down every road, so neither side has it easier.
        for (final lane in _lanes) {
          _launch(spawn, next.wave, lane);
        }
        _spawned++;
        _spawnTimer = GameConfig.enemySpawnEvery;
      }
    }
    if (next.wave > 0 &&
        next.nextWaveAt == 0 &&
        _queue.isEmpty &&
        !gameRef.enemyForcesLeft) {
      // After the last regular wave the host gets a longer break to decide
      // whether to go on.
      // A duel goes on by itself until a base falls.
      final pause =
          next.wave >= GameConfig.defenseWaves && !next.extended && !_duel
          ? GameConfig.extendDecisionSeconds
          : GameConfig.waveBreakSeconds;
      next = _grow(next).copyWith(
        nextWaveAt: _now + pause * 1000,
        extended:
            next.extended || (_duel && next.wave >= GameConfig.defenseWaves),
      );
    }
    _keepalive += dt;
    if (!identical(next, state) || _keepalive >= 1) {
      _keepalive = 0;
      gameRef.publishDefense(next);
    }
  }
}

enum _Spawn { tank, squad, helicopter, jet, drone }

extension on DefenseDirector {
  /// A squad leads the way, the aircraft come in between the tanks, the
  /// drones last.
  List<_Spawn> _order(WavePlan plan) {
    final order = <_Spawn>[for (var i = 0; i < plan.squads; i++) _Spawn.squad];
    final air = [
      for (var i = 0; i < plan.helicopters; i++) _Spawn.helicopter,
      for (var i = 0; i < plan.jets; i++) _Spawn.jet,
    ];
    for (var i = 0; i < plan.tanks; i++) {
      order.add(_Spawn.tank);
      if (i.isOdd && air.isNotEmpty) {
        order.add(air.removeAt(0));
      }
    }
    order
      ..addAll(air)
      ..addAll([for (var i = 0; i < plan.drones; i++) _Spawn.drone]);
    return order;
  }

  /// Sends one of the wave down the road of [lane]. The right road's units
  /// carry a `b` at the end of their id.
  void _launch(_Spawn spawn, int wave, int lane) {
    final n = '$_spawned${lane == 1 ? 'b' : ''}';
    // In a duel the waves on the way to one base fight for the other side.
    final team = _duel ? 2 - lane : 2;
    switch (spawn) {
      case _Spawn.tank:
        gameRef.spawnEnemy('td-$wave-$n', lane: lane, team: team);
      case _Spawn.squad:
        gameRef.spawnEnemySquad('td-i-$wave-$n', wave, lane: lane);
      case _Spawn.helicopter:
        gameRef.spawnAircraft('td-h-$wave-$n', AirKind.helicopter, lane: lane);
      case _Spawn.jet:
        gameRef.spawnAircraft('td-j-$wave-$n', AirKind.jet, lane: lane);
      case _Spawn.drone:
        gameRef.spawnEnemyDrone('td-d-$wave-$n', lane: lane);
    }
  }
}
