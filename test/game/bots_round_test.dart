import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/round_state.dart';
import 'package:wargame/src/net/payloads/round_start_payload.dart';

void main() {
  test('bots travel with the round start and get readable names', () {
    final payload = RoundStartPayload(
      seed: 1,
      startedAt: 2,
      participants: const ['a', 'cpu-1', 'cpu-2'],
      bots: const {'cpu-1': 5, 'cpu-2': 9},
      botHost: 'a',
    );
    final back = RoundStartPayload.fromJson(payload.toJson());
    expect(back.bots, {'cpu-1': 5, 'cpu-2': 9});
    expect(back.botHost, 'a');

    final round = RoundState(
      seed: back.seed,
      startedAt: back.startedAt,
      participants: back.participants,
      bots: back.bots,
      botHost: back.botHost,
    );
    expect(round.isBot('cpu-2'), isTrue);
    expect(round.isBot('a'), isFalse);
    expect(round.botName('cpu-2'), 'CPU-2');
  });

  test('a round without bots has none', () {
    final old = RoundStartPayload.fromJson({
      'seed': 1,
      'startedAt': 2,
      'participants': ['a'],
    });
    expect(old.bots, isEmpty);
    expect(old.botHost, isNull);
  });
}
