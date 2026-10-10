import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/net/net_events.dart';
import 'package:wargame/src/net/payloads/round_start_payload.dart';
import 'package:wargame/src/net/replay.dart';

void main() {
  RoundStartPayload round(int startedAt) => RoundStartPayload(
    seed: 42,
    startedAt: startedAt,
    participants: const ['a', 'b'],
  );

  test('the recorder keeps messages relative to the round start', () {
    final startedAt = clock.now().millisecondsSinceEpoch - 2000;
    final recorder = ReplayRecorder()
      ..start(round(startedAt), names: {'a': 'A'}, styles: {'a': 3});
    recorder
      ..add(NetEvent.shoot, {'id': 'a'})
      ..add(NetEvent.roundStart, {'id': 'a'})
      ..add(NetEvent.death, {'id': 'b'});
    final replay = recorder.finish()!;
    expect(replay.events.map((e) => e.event), [NetEvent.shoot, NetEvent.death]);
    expect(replay.events.first.at, inInclusiveRange(1900, 3000));
    expect(replay.names['a'], 'A');
    expect(recorder.recording, isFalse);
    expect(recorder.finish(), isNull);
  });

  test('nothing is recorded outside a round', () {
    final recorder = ReplayRecorder()..add(NetEvent.shoot, {'id': 'a'});
    expect(recorder.finish(), isNull);
  });

  test('the player hands out messages as their time comes', () {
    final replay = Replay(
      round: round(1000),
      names: const {},
      styles: const {},
      events: const [
        ReplayEvent(-500, NetEvent.state, {}),
        ReplayEvent(100, NetEvent.shoot, {}),
        ReplayEvent(900, NetEvent.death, {}),
      ],
    );
    final player = ReplayPlayer(replay, startedAt: 50000);
    expect(player.shift, 49000);
    expect(player.due(49000).length, 0);
    expect(player.due(49600).length, 1);
    expect(player.due(50000).length, 0);
    expect(player.due(50500).map((e) => e.event), [NetEvent.shoot]);
    expect(player.done, isFalse);
    expect(player.due(51000).map((e) => e.event), [NetEvent.death]);
    expect(player.done, isTrue);
    expect(replay.length, 900);
  });

  test('a long round keeps positions sparser but every shot', () {
    var now = DateTime(2026, 10, 10);
    withClock(Clock(() => now), () {
      final recorder = ReplayRecorder()
        ..start(
          round(now.millisecondsSinceEpoch),
          names: const {},
          styles: const {},
        );
      // Fill up to the point where positions get thinned, at 10 Hz.
      for (var i = 0; i < ReplayRecorder.thinAfter; i++) {
        now = now.add(const Duration(milliseconds: 100));
        recorder.add(NetEvent.state, {'id': 'a'});
      }
      for (var i = 0; i < 100; i++) {
        now = now.add(const Duration(milliseconds: 100));
        recorder
          ..add(NetEvent.state, {'id': 'a'})
          ..add(NetEvent.state, {'id': 'b'})
          ..add(NetEvent.shoot, {'id': 'a'});
      }
      final events = recorder.finish()!.events.skip(ReplayRecorder.thinAfter);
      expect(events.where((e) => e.event == NetEvent.shoot).length, 100);
      // Ten seconds at one position every half second, for each tank.
      final a = events.where(
        (e) => e.event == NetEvent.state && e.payload['id'] == 'a',
      );
      expect(a.length, inInclusiveRange(19, 21));
    });
  });
}
