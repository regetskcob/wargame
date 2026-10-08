import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/defense/defense_map.dart';
import 'package:wargame/src/game/round_state.dart';
import 'package:wargame/src/net/payloads/defense_payload.dart';
import 'package:wargame/src/net/payloads/round_start_payload.dart';

void main() {
  RoundState duel() => RoundState(
    seed: 7,
    startedAt: 0,
    participants: const ['red', 'blue'],
    defense: true,
    lanes: const ['red', 'blue'],
  );

  test('two sides: each player with their troops, base and waves', () {
    final round = duel();
    expect(round.duel, isTrue);
    expect(round.teamOf('red'), 1);
    expect(round.teamOf('blue'), 2);
    // Waves on the way to the right base are red, to the left one blue.
    expect(round.teamOf('td-3-4b'), 1);
    expect(round.teamOf('td-3-4'), 2);
    expect(round.teamOf('td-h-2-1b'), 1);
    // Troops a player sent and the infantry of a base fight for its side.
    expect(round.teamOf('td-s0-2-ab1'), 1);
    expect(round.teamOf('td-s1-2-cd0'), 2);
    expect(round.teamOf('ally-L1-q2-0'), 2);
    expect(round.laneOf('blue'), 1);
    expect(round.laneOf('someone'), 0);
  });

  test('both roads join the two bases, red on the left', () {
    for (var seed = 0; seed < 4 * DefenseMap.layoutCount; seed += 4) {
      final map = DefenseMap.duelForSeed(seed);
      expect(map.duel, isTrue);
      final [left, right] = map.lanes;
      expect(left.base.x, lessThan(right.base.x));
      // One road, driven both ways.
      expect(left.road.first, right.road.last);
      expect(right.road.first, left.road.last);
      expect(map.roads, hasLength(1));
      expect(DefenseMap.bounds.contains(left.base.toOffset()), isTrue);
    }
  });

  test('the duel travels in the round start and the state of the bases', () {
    final start = RoundStartPayload.fromJson(
      const RoundStartPayload(
        seed: 1,
        startedAt: 2,
        participants: ['a', 'b'],
        defense: true,
        lanes: ['a', 'b'],
      ).toJson(),
    );
    expect(start.lanes, ['a', 'b']);
    final state = DefensePayload.fromJson(
      const DefensePayload(
        id: 'a',
        hp: 10,
        hp2: 20,
        hq2: 2,
        wave: 3,
        fell: 1,
      ).toJson(),
    );
    expect(state.duel, isTrue);
    expect(state.hpOf(1), 20);
    expect(state.hqOf(1), 2);
    expect(state.fell, 1);
    expect(state.withBase(1, hp: 5).hpOf(1), 5);
    expect(state.withBase(0, hp: 5).hpOf(1), 20);
  });

  test('a troop order reads back, broken ones are dropped', () {
    final order = TroopsPayload.tryParse(
      const TroopsPayload(id: 'a', serial: 3).toJson(),
    );
    expect(order?.id, 'a');
    expect(order?.serial, 3);
    expect(TroopsPayload.tryParse({'id': 4, 'n': 1}), isNull);
    expect(TroopsPayload.tryParse({'id': 'a', 'n': -1}), isNull);
    expect(TroopsPayload.tryParse({'id': 'a'}), isNull);
  });
}
