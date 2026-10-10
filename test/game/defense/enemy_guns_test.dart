import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/defense/tower.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/tank_game.dart';

import '../../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<TankGame> defenseRound({bool playing = false}) async {
    final game = await loadedGame();
    game
      ..update(0)
      ..chooseMode(GameMode.defense)
      ..startRound();
    if (playing) {
      // Past the countdown, which runs on the clock, so guns can be built.
      await Future<void>.delayed(const Duration(seconds: 3, milliseconds: 100));
      game.update(0);
      expect(game.phase.value, GamePhase.playing);
    }
    return game;
  }

  test('the enemy digs in guns from its third wave and the two sides fire '
      'on each other\'s guns', () async {
    final game = await defenseRound();
    expect(game.round?.botHost, game.myId);
    game.digInEnemyGuns(GameConfig.enemyGunsFromWave - 1);
    expect(game.towers, isEmpty);
    game
      ..digInEnemyGuns(7)
      ..update(0);
    final enemy = game.towers.values
        .where((t) => t.ownerId == TankGame.enemyGunOwner)
        .toList();
    expect(enemy, hasLength(GameConfig.enemyGunsIn(7)));
    expect(enemy.map((t) => t.kind).toSet(), {
      TowerKind.cannon,
      TowerKind.flak,
    });
    expect(enemy.first.level, GameConfig.enemyGunLevelIn(7));
    // Building again for the same wave adds nothing.
    game.digInEnemyGuns(7);
    expect(game.towers, hasLength(enemy.length));

    expect(game.hurtsTower(game.myId, TankGame.enemyGunOwner), isTrue);
    expect(game.hurtsTower('ally-0-0', TankGame.enemyGunOwner), isTrue);
    expect(game.hurtsTower('td-3-1', TankGame.enemyGunOwner), isFalse);
    expect(game.hurtsTower('td-3-1', game.myId), isTrue);
    expect(game.hurtsTower(game.myId, game.myId), isFalse);

    final gun = enemy.first;
    expect(game.nearestTower(gun.position, 50, of: game.myId), gun);
    expect(game.nearestTower(gun.position, 50, of: 'td-3-1'), isNull);
  });

  test('destroying an enemy gun pays the one who hit it last', () async {
    final game = await defenseRound();
    game
      ..digInEnemyGuns(GameConfig.enemyGunsFromWave)
      ..update(0);
    final gun = game.towers.values.single;
    final before = game.credits.value;
    gun.lastHitBy = game.myId;
    game.damageTower(gun, gun.hp + 1);
    expect(game.towers, isEmpty);
    expect(
      game.credits.value - before,
      GameConfig.bountyIn(GameConfig.creditsPerGun, game.defense.value!.wave),
    );
  });

  test('every further gun of one kind costs more', () async {
    final game = await defenseRound(playing: true);
    final first = game.buildCost(TowerKind.flak);
    expect(first, TowerKind.flak.cost);
    game.credits.value = 10000;
    game.buildTower(TowerKind.flak);
    expect(game.towers, hasLength(1), reason: game.notice.value);
    expect(game.buildCost(TowerKind.flak), greaterThan(first));
    expect(game.buildCost(TowerKind.cannon), TowerKind.cannon.cost);
    expect(game.credits.value, 10000 - first);
  });

  test('a trench covers its own side, not the enemy rolling over it', () async {
    final game = await defenseRound(playing: true);
    final tank = game.myTank!;
    game
      ..credits.value = 1000
      // Trenches come up with the second wave.
      ..defense.value = game.defense.value!.copyWith(
        wave: TowerKind.trench.fromWave,
      )
      ..buildTower(TowerKind.trench);
    game.update(0);
    final trench = game.towers.values.single;
    expect(trench.kind, TowerKind.trench);
    expect(game.inTrench(trench.position, of: game.myId), isTrue);
    expect(game.inTrench(trench.position, of: 'ally-0-0'), isTrue);
    expect(game.inTrench(trench.position, of: 'td-3-1'), isFalse);
    expect(tank.position.distanceTo(trench.position), lessThan(1));
  });
}
