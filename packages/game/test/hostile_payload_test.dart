import 'package:flutter_test/flutter_test.dart';
import 'package:game/src/net/payloads/defense_payload.dart';
import 'package:game/src/net/payloads/lobby_presence.dart';
import 'package:game/src/net/room_directory.dart';

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
}
