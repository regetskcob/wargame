import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/src/game_config.dart';
import 'package:game/src/game/defense/defense_map.dart';
import 'package:game/src/game/defense/tower.dart';
import 'package:game/src/game/round_state.dart';
import 'package:game/src/net/payloads/defense_payload.dart';
import 'package:game/src/net/payloads/lobby_presence.dart';
import 'package:game/src/net/payloads/round_start_payload.dart';
import 'package:game/src/net/payloads/shoot_payload.dart';

void main() {
  test('players defend together, every enemy is on the other side', () {
    final round = RoundState(
      seed: 1,
      startedAt: 2,
      participants: const ['a', 'b'],
      botHost: 'a',
      defense: true,
    );
    expect(round.teamOf('a'), 1);
    expect(round.teamOf('b'), 1);
    expect(round.teamOf('td-3-1'), 2);
    expect(round.isEnemy('td-3-1'), isTrue);
    expect(round.isBot('td-3-1'), isTrue);
    expect(round.isEnemy('a'), isFalse);
    expect(round.botName('td-3-1'), 'FEIND');
    expect(round.teamMode, isFalse);
  });

  test('outside a defense round td ids are nothing special', () {
    final round = RoundState(seed: 1, startedAt: 2, participants: const ['a']);
    expect(round.isEnemy('td-1-1'), isFalse);
    expect(round.teamOf('td-1-1'), 0);
  });

  test('the defense flag and gun shots travel over the wire', () {
    final start = RoundStartPayload.fromJson(
      const RoundStartPayload(
        seed: 5,
        startedAt: 6,
        participants: ['a'],
        botHost: 'a',
        defense: true,
      ).toJson(),
    );
    expect(start.defense, isTrue);
    expect(start.botHost, 'a');
    expect(
      RoundStartPayload.fromJson({
        'seed': 1,
        'startedAt': 2,
        'participants': ['a'],
      }).defense,
      isFalse,
    );

    final state = DefensePayload.fromJson(
      const DefensePayload(
        id: 'a',
        hp: 800,
        wave: 3,
        nextWaveAt: 99,
        result: DefenseResult.lost,
      ).toJson(),
    );
    expect(state.hp, 800);
    expect(state.wave, 3);
    expect(state.nextWaveAt, 99);
    expect(state.result, DefenseResult.lost);

    final tower = TowerPayload.fromJson(
      const TowerPayload(id: 'a', index: 2, x: 1, y: -3).toJson(),
    );
    expect((tower.index, tower.x, tower.y), (2, 1.0, -3.0));

    final shot = ShootPayload.fromJson(
      const ShootPayload(
        id: 'a',
        bulletId: 'a-1',
        x: 0,
        y: 0,
        dx: 1,
        dy: 0,
        tower: 2,
      ).toJson(),
    );
    expect(shot.tower, 2);

    final presence = LobbyPresence.fromJson(
      const LobbyPresence(
        id: 'a',
        name: 'A',
        colorIndex: 0,
        phase: 'playing',
        seed: 1,
        startedAt: 2,
        defense: true,
        botHost: 'a',
      ).toJson(),
    );
    expect(presence.defense, isTrue);
    expect(presence.botHost, 'a');
  });

  test('every layout runs from the edge to the base inside the field', () {
    for (var seed = 0; seed < 12; seed++) {
      final map = DefenseMap.forSeed(seed);
      for (final point in map.road) {
        expect(DefenseMap.bounds.inflate(1).contains(point.toOffset()), isTrue);
      }
      final entry = map.entry;
      expect(
        entry.x.abs() == DefenseMap.halfWidth ||
            entry.y.abs() == DefenseMap.halfHeight,
        isTrue,
      );
      for (var i = 0; i < 4; i++) {
        final spawn = map.spawnFor(i, 4);
        expect(
          map.distanceToRoad(spawn),
          greaterThan(DefenseMap.roadHalfWidth),
        );
      }
    }
  });

  test('guns stay off the road, away from the base and from each other', () {
    final map = DefenseMap.forSeed(0);
    expect(map.whyNotBuild(map.road[1], const []), isNotNull);
    expect(map.whyNotBuild(map.base, const []), isNotNull);
    final free = map.road[1] + Vector2(0, 0) + Vector2(150, -150);
    expect(map.distanceToRoad(free), greaterThan(100));
    expect(map.whyNotBuild(free, const []), isNull);
    expect(map.whyNotBuild(free, [free + Vector2(20, 0)]), isNotNull);
  });

  test('CPU comrades fight on the side of the players', () {
    final round = RoundState(
      seed: 1,
      startedAt: 2,
      participants: const ['a'],
      botHost: 'a',
      defense: true,
    );
    expect(round.isAlly('ally-0-3'), isTrue);
    expect(round.isEnemy('ally-0-3'), isFalse);
    expect(round.isBot('ally-0-3'), isTrue);
    expect(round.teamOf('ally-0-3'), round.teamOf('a'));
    expect(round.botName('ally-1-0'), 'KAMERAD 2');
    expect(
      RoundState(
        seed: 1,
        startedAt: 2,
        participants: const ['a'],
      ).isAlly('ally-0-0'),
      isFalse,
    );
  });

  test('comrades keep watch beside the road, inside the field', () {
    for (var seed = 0; seed < 12; seed += 4) {
      final map = DefenseMap.forSeed(seed);
      for (var slot = 0; slot < 4; slot++) {
        final post = map.allyPost(slot);
        expect(DefenseMap.bounds.contains(post.toOffset()), isTrue);
        expect(
          map.distanceToRoad(post),
          greaterThan(DefenseMap.roadHalfWidth + 10),
        );
        expect(
          map.distanceToRoad(post),
          lessThan(DefenseMap.roadHalfWidth + 40),
        );
        final route = map.allyRoute(slot);
        expect(route.last, post);
        for (final point in route.take(route.length - 1)) {
          expect(map.distanceToRoad(point), lessThan(1));
        }
      }
    }
  });

  test('the base sends aircraft of its own that fly for the defenders', () {
    final round = RoundState(
      seed: 1,
      startedAt: 2,
      participants: const ['a'],
      botHost: 'a',
      defense: true,
    );
    expect(round.isFriendlyAir('air-h-3'), isTrue);
    expect(round.isEnemy('air-h-3'), isFalse);
    expect(round.teamOf('air-j-5'), round.teamOf('a'));
    expect(round.botName('air-h-3'), 'EIGENER HUBSCHRAUBER');
    expect(round.botName('air-j-5'), 'EIGENER JET');
    expect(round.botName('td-h-3-1'), 'HUBSCHRAUBER');
  });

  test('howitzer and trench come up later in the round', () {
    expect(TowerKind.cannon.unlockedIn(0), isTrue);
    expect(TowerKind.trench.unlockedIn(1), isFalse);
    expect(TowerKind.trench.unlockedIn(2), isTrue);
    expect(TowerKind.howitzer.unlockedIn(3), isFalse);
    expect(TowerKind.howitzer.unlockedIn(4), isTrue);
    expect(TowerKind.howitzer.range, greaterThan(TowerKind.mortar.range));
    expect(TowerKind.howitzer.lobs, isTrue);
    expect(TowerKind.trench.isGun, isFalse);
    expect(TowerKind.trench.upgradable, isFalse);
  });

  test('the base grows with waves held without heavy losses', () {
    expect(GameConfig.hqLevelFor(0), 1);
    expect(GameConfig.hqLevelFor(1), 1);
    expect(GameConfig.hqLevelFor(2), 2);
    expect(GameConfig.hqLevelFor(4), 3);
    expect(GameConfig.hqLevelFor(9), 3);
    expect(GameConfig.baseMaxHp(3), greaterThan(GameConfig.baseMaxHp(1)));
    expect(GameConfig.hqName(2), 'KASERNE');
    final state = DefensePayload.fromJson(
      const DefensePayload(id: 'a', hp: 1, wave: 2, hq: 3).toJson(),
    );
    expect(state.hq, 3);
    expect(
      DefensePayload.fromJson(
        const DefensePayload(id: 'a', hp: 1, wave: 2).toJson(),
      ).hq,
      1,
    );
  });

  test('guns can be shot to pieces, their hit points travel', () {
    for (final kind in TowerKind.values) {
      expect(kind.maxHpAt(1), greaterThan(0));
      expect(kind.maxHpAt(3), greaterThan(kind.maxHpAt(1)));
    }
    final hit = TowerPayload.fromJson(
      const TowerPayload(id: 'a', index: 1, x: 0, y: 0, hp: 12.5).toJson(),
    );
    expect(hit.hp, 12.5);
    expect(
      TowerPayload.fromJson(
        const TowerPayload(id: 'a', index: 1, x: 0, y: 0).toJson(),
      ).hp,
      isNull,
    );
  });

  test('later waves are bigger', () {
    expect(DefenseMap.waveSize(8), greaterThan(DefenseMap.waveSize(1)));
  });
}
