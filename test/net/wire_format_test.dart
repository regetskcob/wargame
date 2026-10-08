import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/net/net_events.dart';
import 'package:wargame/src/net/payloads/lobby_presence.dart';
import 'package:wargame/src/net/payloads/round_start_payload.dart';
import 'package:wargame/src/net/payloads/shoot_payload.dart';
import 'package:wargame/src/net/payloads/tank_state_payload.dart';

/// The web game updates at once, the apps only with the next store build,
/// so every room mixes versions. These tests keep the wire stable: an event
/// that is renamed or a field that is no longer written leaves older clients
/// deaf to it, as happened when the CPU tanks moved into `states`. Adding
/// events and optional fields is fine; take an entry out of these lists
/// only on purpose, knowing older clients break.

/// Events clients send and listen to, by their wire name.
const _events = [
  'state',
  'states',
  'shoot',
  'hit',
  'death',
  'roundStart',
  'pickup',
  'smoke',
  'obstacle',
  'soldier',
  'mine',
  'artillery',
  'defense',
  'tower',
  'grenade',
  'drone',
  'blast',
  'air',
  'squad',
  'use',
  'close',
  'troops',
];

/// The fields every client reads, as the oldest supported ones send them.
const _oldTankState = {
  'id': 'a',
  'x': 1,
  'y': 2,
  'vx': 0,
  'vy': 0,
  'rot': 0.5,
  'hp': 80,
};
const _oldPresence = {'id': 'a', 'name': 'Wolf', 'color': 1, 'phase': 'lobby'};
const _oldRoundStart = {
  'seed': 7,
  'startedAt': 1000,
  'participants': ['a', 'b'],
};
const _oldShot = {
  'id': 'a',
  'bulletId': 'a-1',
  'x': 1,
  'y': 2,
  'dx': 3,
  'dy': 4,
};

void main() {
  test('no event older clients know has gone or been renamed', () {
    final names = {for (final event in NetEvent.values) event.name};
    for (final name in _events) {
      expect(
        names,
        contains(name),
        reason:
            'Older clients still send and wait for "$name". Keep the enum '
            'value and its name (see /net-event).',
      );
    }
  });

  group('messages of older clients still parse', () {
    test('tank state', () {
      final state = TankStatePayload.fromJson(_oldTankState);
      expect(state.turret, isNull);
      expect(state.shielded, isFalse);
    });

    test('presence', () {
      final presence = LobbyPresence.tryParse(_oldPresence);
      expect(presence, isNotNull);
      expect(presence!.joinedAt, isNull);
      expect(presence.pad, isFalse);
    });

    test('round start', () {
      final start = RoundStartPayload.fromJson(_oldRoundStart);
      expect(start.bots, isEmpty);
      expect(start.defense, isFalse);
    });

    test('shot', () {
      final shot = ShootPayload.fromJson(_oldShot);
      expect(shot.bulletId, 'a-1');
    });
  });

  group('every field older clients read is still written', () {
    void keeps(Map<String, dynamic> written, Map<String, Object> old) {
      expect(
        written.keys,
        containsAll(old.keys),
        reason: 'Older clients read these fields and break without them.',
      );
    }

    test('tank state, alone and in the CPU tanks\' batch', () {
      const state = TankStatePayload(
        id: 'a',
        x: 1,
        y: 2,
        vx: 0,
        vy: 0,
        rotation: 0.5,
        hp: 80,
      );
      keeps(state.toJson(), _oldTankState);
      final batch = const TankStatesPayload(
        id: 'host',
        states: [state],
      ).toJson();
      keeps(
        ((batch['states'] as List).single as Map).cast<String, dynamic>(),
        _oldTankState,
      );
    });

    test('presence', () {
      const presence = LobbyPresence(
        id: 'a',
        name: 'Wolf',
        colorIndex: 1,
        phase: 'lobby',
      );
      keeps(presence.toJson(), _oldPresence);
    });

    test('round start', () {
      const start = RoundStartPayload(
        seed: 7,
        startedAt: 1000,
        participants: ['a', 'b'],
      );
      keeps(start.toJson(), _oldRoundStart);
    });

    test('shot', () {
      keeps(ShootPayload.fromJson(_oldShot).toJson(), _oldShot);
    });
  });
}
