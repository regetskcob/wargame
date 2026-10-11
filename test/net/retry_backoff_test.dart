import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/net/net_events.dart';
import 'package:wargame/src/net/net_service.dart';
import 'package:wargame/src/net/payloads/lobby_presence.dart';
import 'package:wargame/src/net/payloads/shoot_payload.dart';
import 'package:wargame/src/net/retry_backoff.dart';

void main() {
  test('a channel that stays down is asked less and less often', () {
    final backoff = RetryBackoff();
    final waits = [for (var i = 0; i < 7; i++) backoff.next().inSeconds];
    expect(waits, [2, 4, 8, 16, 30, 30, 30]);
    expect(backoff.failures, 7);
    backoff.reset();
    expect(backoff.next(), const Duration(seconds: 2));
  });

  test('only a channel that stays up starts over at the short wait', () {
    fakeAsync((async) {
      final backoff = RetryBackoff();
      // A flood above the project's limit: every join gets through and is
      // closed again at once. The waits keep growing.
      final waits = <int>[];
      for (var i = 0; i < 5; i++) {
        waits.add(backoff.next().inSeconds);
        async.elapse(const Duration(milliseconds: 5));
        backoff.up();
        async.elapse(const Duration(milliseconds: 5));
      }
      expect(waits, [2, 4, 8, 16, 30]);
      // Up for long enough: the next drop is the first again.
      async.elapse(backoff.stableAfter);
      expect(backoff.next(), const Duration(seconds: 2));
    });
  });

  test('a failed fire-and-forget future is logged, not thrown', () async {
    fireAndForget(Future<void>.error(StateError('gone')), 'Sending');
    // Would fail the test as an uncaught async error otherwise.
    await pumpEventQueue();
  });

  test(
    'a malformed message is dropped and the next one still arrives',
    () async {
      final host = NetService(myId: 'a', room: 'r');
      final guest = NetService(myId: 'b', room: 'r');
      LocalLink(host, guest);
      await guest.connect(
        const LobbyPresence(id: 'b', name: 'b', colorIndex: 0, phase: 'lobby'),
      );
      final shots = <ShootPayload>[];
      guest.onShoot = shots.add;
      host
        ..send(NetEvent.shoot, {'id': 'a', 'bulletId': 1, 'x': 'left'})
        ..send(NetEvent.shoot, {
          'id': 'a',
          'bulletId': 'a1',
          'x': 1,
          'y': 2,
          'dx': 0,
          'dy': 1,
        });
      await pumpEventQueue();
      expect(shots.map((s) => s.bulletId), ['a1']);
    },
  );
}
