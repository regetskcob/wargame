import 'package:flame/components.dart';

import '../../game_config.dart';
import '../../net/payloads/defense_payload.dart';
import '../game_phase.dart';
import '../space_game.dart';
import 'defense_map.dart';

/// Runs the waves of a defense round. Only the player who simulates the
/// enemies has one: it spawns them, keeps the score of the base and tells the
/// others how it stands.
class DefenseDirector extends Component with HasGameRef<SpaceGame> {
  DefenseDirector({required this.startedAt});

  final int startedAt;

  int _queued = 0;
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
    var next = state;
    if (state.hp <= 0) {
      gameRef.publishDefense(state.copyWith(hp: 0, result: DefenseResult.lost));
      return;
    }
    if (state.nextWaveAt > 0 && _now >= state.nextWaveAt) {
      next = state.copyWith(wave: state.wave + 1, nextWaveAt: 0);
      _queued = DefenseMap.waveSize(next.wave);
      _spawned = 0;
      _spawnTimer = 0;
    }
    _spawnTimer -= dt;
    if (_queued > 0 &&
        _spawnTimer <= 0 &&
        gameRef.botShips.length < GameConfig.maxEnemiesAlive) {
      gameRef.spawnEnemy('td-${next.wave}-$_spawned');
      _spawned++;
      _queued--;
      _spawnTimer = GameConfig.enemySpawnEvery;
    }
    if (next.wave > 0 &&
        next.nextWaveAt == 0 &&
        _queued == 0 &&
        gameRef.botShips.isEmpty) {
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
