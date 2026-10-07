import 'package:flame/components.dart';

import '../../game_config.dart';
import '../../net/payloads/defense_payload.dart';
import '../game_phase.dart';
import '../space_game.dart';
import 'aircraft.dart';
import 'defense_map.dart';

/// Runs the waves of a defense round. Only the player who simulates the
/// enemies has one: it spawns them and the CPU comrades, keeps the score of
/// the base and tells the others how it stands.
class DefenseDirector extends Component with HasGameRef<SpaceGame> {
  DefenseDirector({required this.startedAt, required this.allies});

  final int startedAt;

  /// Number of CPU comrades on the side of the players.
  final int allies;

  /// Per comrade slot: the tank on the field, how often it was sent and the
  /// seconds until the next one rolls out of the base.
  late final _allyIds = List<String?>.filled(allies, null);
  late final _allyLives = List<int>.filled(allies, 0);
  late final _allyWait = List<double>.filled(allies, 0);

  final _queue = <_Spawn>[];
  int _spawned = 0;
  double _spawnTimer = 0;
  double _keepalive = 0;

  int get _now => DateTime.now().millisecondsSinceEpoch;

  @override
  void onMount() {
    super.onMount();
    gameRef.publishDefense(
      DefensePayload(
        id: gameRef.myId,
        hp: GameConfig.baseHp,
        wave: 0,
        nextWaveAt: startedAt + GameConfig.firstWaveSeconds * 1000,
      ),
    );
    for (var slot = 0; slot < allies; slot++) {
      _sendAlly(slot);
    }
  }

  void _sendAlly(int slot) {
    final id = 'ally-$slot-${_allyLives[slot]++}';
    _allyIds[slot] = id;
    gameRef.spawnAlly(id, slot);
  }

  /// Sends a fresh comrade for every one that was destroyed, after a while.
  void _keepAllies(double dt) {
    for (var slot = 0; slot < allies; slot++) {
      final id = _allyIds[slot];
      if (id != null && gameRef.botShips.containsKey(id)) {
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
    if (state.hp <= 0) {
      gameRef.publishDefense(state.copyWith(hp: 0, result: DefenseResult.lost));
      return;
    }
    if (state.nextWaveAt > 0 && _now >= state.nextWaveAt) {
      next = state.copyWith(wave: state.wave + 1, nextWaveAt: 0);
      _queue
        ..clear()
        ..addAll(_order(DefenseMap.planFor(next.wave)));
      _spawned = 0;
      _spawnTimer = 0;
    }
    _spawnTimer -= dt;
    if (_queue.isNotEmpty && _spawnTimer <= 0) {
      final spawn = _queue.first;
      final room =
          spawn != _Spawn.tank ||
          gameRef.enemiesAlive < GameConfig.maxEnemiesAlive;
      if (room) {
        _queue.removeAt(0);
        _launch(spawn, next.wave);
        _spawned++;
        _spawnTimer = GameConfig.enemySpawnEvery;
      }
    }
    if (next.wave > 0 &&
        next.nextWaveAt == 0 &&
        _queue.isEmpty &&
        !gameRef.enemyForcesLeft) {
      next = next.wave >= GameConfig.defenseWaves
          ? next.copyWith(result: DefenseResult.won)
          : next.copyWith(
              nextWaveAt: _now + GameConfig.waveBreakSeconds * 1000,
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

  void _launch(_Spawn spawn, int wave) {
    final n = _spawned;
    switch (spawn) {
      case _Spawn.tank:
        gameRef.spawnEnemy('td-$wave-$n');
      case _Spawn.squad:
        gameRef.spawnEnemySquad('td-i-$wave-$n', wave);
      case _Spawn.helicopter:
        gameRef.spawnAircraft('td-h-$wave-$n', AirKind.helicopter);
      case _Spawn.jet:
        gameRef.spawnAircraft('td-j-$wave-$n', AirKind.jet);
      case _Spawn.drone:
        gameRef.spawnEnemyDrone('td-d-$wave-$n');
    }
  }
}
