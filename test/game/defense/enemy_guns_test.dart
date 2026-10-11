import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/components/bullet.dart';
import 'package:wargame/src/game/defense/aircraft.dart';
import 'package:wargame/src/game/defense/defense_map.dart';
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

  test('a trench dug on the road lies across it from edge to edge and slows '
      'every tank over it', () async {
    final game = await defenseRound(playing: true);
    final map = game.defenseMap!;
    final (centre, dir) = map.alongRoad(map.roadLength * 0.3);
    final side = Vector2(-dir.y, dir.x);
    game.myTank!.position.setFrom(centre + side * 25);
    game
      ..credits.value = 1000
      ..defense.value = game.defense.value!.copyWith(
        wave: TowerKind.trench.fromWave,
      )
      ..buildTower(TowerKind.trench);
    game.update(0);
    final trench = game.towers.values.single;
    expect(trench.onRoad, isTrue, reason: game.notice.value);
    // Dug on the middle of the road, wherever on it the tank stood.
    expect(trench.position.distanceTo(centre), lessThan(1));
    expect(trench.trenchAxis.dot(dir).abs(), lessThan(0.01));
    for (final edge in [-1.0, 1.0]) {
      final at = centre + side * (edge * (DefenseMap.roadHalfWidth - 4));
      expect(game.overTrench(at), isTrue);
    }
    expect(game.overTrench(centre + dir * 60), isFalse);
    expect(trench.crew, Tower.trenchCrew);
  });

  test('the men in a trench fire at soldiers marching past', () async {
    final game = await defenseRound(playing: true);
    final map = game.defenseMap!;
    final (point, dir) = map.alongRoad(160);
    // Beside the road, in reach of the soldiers coming in.
    game.myTank!.position.setFrom(
      point + Vector2(-dir.y, dir.x) * (DefenseMap.roadHalfWidth + 40),
    );
    game
      ..credits.value = 1000
      ..defense.value = game.defense.value!.copyWith(
        wave: TowerKind.trench.fromWave,
      )
      ..buildTower(TowerKind.trench)
      ..spawnEnemySquad('td-s-2-0', 2);
    game.update(0);
    final trench = game.towers.values.single;
    expect(trench.onRoad, isFalse, reason: game.notice.value);
    // Beside the road it runs along it.
    expect(trench.trenchAxis.dot(dir).abs(), greaterThan(0.99));
    final before = game.bullets.length;
    for (var i = 0; i < 10; i++) {
      game.update(0.2);
    }
    expect(game.bullets.length, greaterThan(before));
  });

  test(
    'a flak shell bursts next to a jet, a cannon shell flies past',
    () async {
      final game = await defenseRound(playing: true);
      game
        ..spawnAircraft('td-j-3-0', AirKind.jet)
        ..update(0);
      final jet = game.aircraft.values.single;
      Bullet shell(String id, TowerKind kind) => Bullet(
        bulletId: id,
        ownerId: game.myId,
        position: jet.position + Vector2(0, -26),
        velocity: Vector2.zero(),
        color: const Color(0xFF000000),
        damage: kind.groundDamageAt(1),
        airDamage: kind.airDamageAt(1),
        antiAir: kind.antiAir,
        burst: kind.burst,
      );
      final cannon = shell('c', TowerKind.cannon);
      game.world.add(cannon);
      game.update(0);
      expect(jet.hp, GameConfig.jetHp);
      expect(cannon.isMounted, isTrue);
      final flak = shell('f', TowerKind.flak)
        ..position.setFrom(cannon.position);
      game.world.add(flak);
      game.update(0);
      game.update(0.001);
      expect(jet.hp, GameConfig.jetHp - TowerKind.flak.airDamageAt(1));
      // It burst once and is gone the tick after.
      game.update(0.001);
      expect(jet.hp, GameConfig.jetHp - TowerKind.flak.airDamageAt(1));
      expect(flak.isRemoving || !flak.isMounted, isTrue);
    },
  );
}
