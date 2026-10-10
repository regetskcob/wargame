import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/round_state.dart';
import 'package:wargame/src/net/payloads/lobby_presence.dart';

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

  test('a doubled host settles on one, even between two owners', () {
    LobbyPresence host(String id, {bool owner = false}) => LobbyPresence(
      id: id,
      name: id,
      colorIndex: 0,
      phase: 'lobby',
      host: true,
      owner: owner,
    );
    // The owner keeps the role against a stand-in, whatever the ids.
    expect(host('b', owner: true).outranksHost('a', iOwn: false), isTrue);
    expect(host('a').outranksHost('b', iOwn: true), isFalse);
    // Two stand-ins: the smaller id stays.
    expect(host('a').outranksHost('b', iOwn: false), isTrue);
    expect(host('b').outranksHost('a', iOwn: false), isFalse);
    // The same browser in two tabs: both own the room, one of them yields.
    expect(host('a', owner: true).outranksHost('b', iOwn: true), isTrue);
    expect(host('b', owner: true).outranksHost('a', iOwn: true), isFalse);
    // Nobody outranks themselves or without claiming the role.
    expect(host('a').outranksHost('a', iOwn: false), isFalse);
    expect(
      const LobbyPresence(
        id: 'a',
        name: 'a',
        colorIndex: 0,
        phase: 'lobby',
        owner: true,
      ).outranksHost('b', iOwn: true),
      isFalse,
    );
  });
}
