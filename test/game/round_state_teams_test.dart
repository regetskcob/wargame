import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/round_state.dart';
import 'package:wargame/src/net/payloads/round_start_payload.dart';

void main() {
  test('two teams make a team round and count their survivors', () {
    final round = RoundState(
      seed: 1,
      startedAt: 0,
      participants: const ['a', 'b', 'c', 'd'],
      teams: const {'a': 1, 'b': 1, 'c': 2, 'd': 2},
    );
    expect(round.teamMode, isTrue);
    expect(round.aliveIn(1), 2);
    round.alive.remove('a');
    expect(round.aliveIn(1), 1);
    expect(round.teamOf('c'), 2);
  });

  test('without teams, or with one team, it stays a free for all', () {
    expect(
      RoundState(
        seed: 1,
        startedAt: 0,
        participants: const ['a', 'b'],
      ).teamMode,
      isFalse,
    );
    expect(
      RoundState(
        seed: 1,
        startedAt: 0,
        participants: const ['a', 'b'],
        teams: const {'a': 1, 'b': 1},
      ).teamMode,
      isFalse,
    );
  });

  test('teams survive the round start payload', () {
    final payload = RoundStartPayload(
      seed: 3,
      startedAt: 9,
      participants: const ['a', 'b'],
      teams: const {'a': 1, 'b': 2},
    );
    final back = RoundStartPayload.fromJson(payload.toJson());
    expect(back.teams, {'a': 1, 'b': 2});
    // Older clients send no teams at all.
    final old = RoundStartPayload.fromJson({
      'seed': 1,
      'startedAt': 2,
      'participants': ['a'],
    });
    expect(old.teams, isEmpty);
  });
}
