import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/net/payloads/defense_payload.dart';
import 'package:wargame/src/net/payloads/lobby_presence.dart';
import 'package:wargame/src/net/payloads/tank_state_payload.dart';
import 'package:wargame/src/net/room_directory.dart';

/// Anybody can put anything on the channels. These messages come from
/// clients that do not play by the rules.
void main() {
  test('a presence with wrong types is skipped, not thrown', () {
    expect(LobbyPresence.tryParse({}), isNull);
    expect(
      LobbyPresence.tryParse({
        'id': 'x',
        'name': 'Eve',
        'color': 1,
        'phase': 'lobby',
        'team': 'red',
      }),
      isNull,
    );
    expect(
      LobbyPresence.tryParse({
        'id': 'x',
        'name': 'Eve',
        'color': 1,
        'phase': 'lobby',
        'host': 1,
      }),
      isNull,
    );
    final ok = LobbyPresence.tryParse({
      'id': 'x',
      'name': 'Eve',
      'color': 1,
      'phase': 'lobby',
    });
    expect(ok?.id, 'x');
  });

  test('overlong call signs are cut', () {
    final member = LobbyPresence.tryParse({
      'id': 'x',
      'name': 'A' * 5000,
      'color': 1,
      'phase': 'lobby',
    });
    expect(member!.name.length, LobbyPresence.maxName);
  });

  test('an unknown defense result does not crash the round', () {
    final state = DefensePayload.fromJson({
      'id': 'h',
      'hp': 10,
      'wave': 3,
      'result': 99,
    });
    expect(state.result, DefenseResult.values.last);
  });

  test('a room listing with a long host name is cut', () {
    final listing = RoomListing.fromJson({'room': 'ABC', 'host': 'B' * 300});
    expect(listing.host.length, 16);
  });

  group('CPU tank states in one message', () {
    TankStatePayload state(String id) => TankStatePayload(
      id: id,
      x: 1,
      y: 2,
      vx: 3,
      vy: 4,
      rotation: 0.5,
      hp: 80,
      turret: 1,
    );

    test('come through whole', () {
      final sent = TankStatesPayload(
        id: 'host',
        states: [state('cpu-1'), state('cpu-2')],
      );
      final back = TankStatesPayload.fromJson(sent.toJson());
      expect(back.id, 'host');
      expect(back.states.map((s) => s.id), ['cpu-1', 'cpu-2']);
      expect(back.states.first.turret, 1);
    });

    test('a flood of states is refused', () {
      final flood = TankStatesPayload(
        id: 'eve',
        states: [
          for (var i = 0; i <= TankStatesPayload.maxStates; i++) state('t$i'),
        ],
      ).toJson();
      expect(
        () => TankStatesPayload.fromJson(flood),
        throwsA(isA<FormatException>()),
      );
    });

    test('a broken entry fails the whole message', () {
      expect(
        () => TankStatesPayload.fromJson({
          'id': 'eve',
          'states': ['nope'],
        }),
        throwsA(anything),
      );
    });
  });
}
