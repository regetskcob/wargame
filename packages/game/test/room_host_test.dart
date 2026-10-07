import 'package:flutter_test/flutter_test.dart';
import 'package:game/src/game/round_state.dart';
import 'package:game/src/net/payloads/lobby_presence.dart';

void main() {
  test('rounds against CPU tanks keep camouflage', () {
    RoundState round(Map<String, int> bots) => RoundState(
      seed: 1,
      startedAt: 0,
      participants: ['a', 'b', ...bots.keys],
      bots: bots,
    );
    expect(round(const {}).distinctColors, isTrue);
    expect(round(const {'cpu-1': 0}).distinctColors, isFalse);
  });

  test('the owner of the room travels with the presence', () {
    const me = LobbyPresence(
      id: 'a',
      name: 'A',
      colorIndex: 0,
      phase: 'lobby',
      host: true,
      owner: true,
    );
    final back = LobbyPresence.fromJson(me.toJson());
    expect(back.owner, isTrue);
    expect(back.host, isTrue);
  });
}
