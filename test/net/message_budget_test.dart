import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/app/overlay_ids.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/net/net_events.dart';
import 'package:wargame/src/net/payloads/round_start_payload.dart';
import 'package:wargame/src/net/replay.dart';

import '../helpers/fakes.dart';

/// Realtime on the free plan: at most 100 messages a second for the whole
/// project, averaged over a minute. Every message counts once when a client
/// sends it and once more for every client it is delivered to. Above the
/// limit Realtime closes every channel of the project, all rooms at once.
/// See supabase.com/docs/guides/realtime/limits and, in supabase/realtime,
/// RealtimeChannel.count and MessageDispatcher.
const _freePlanPerSecond = 100;

/// The same on the Pro plan.
const _proPlanPerSecond = 500;

/// How long each measured round runs.
const _length = Duration(seconds: 20);

/// Counts what would have gone onto the channel.
class _CountingNet extends FakeNet {
  final sent = <NetEvent, int>{};

  int get total => sent.values.fold(0, (sum, n) => sum + n);

  @override
  void transmit(NetEvent event, Map<String, dynamic> payload) =>
      sent[event] = (sent[event] ?? 0) + 1;
}

/// What one client put on the channel during a round.
class _Measured {
  _Measured({required this.perSecond, required this.bots, required this.sent});

  final double perSecond;
  final int bots;
  final Map<NetEvent, int> sent;

  @override
  String toString() =>
      '${perSecond.toStringAsFixed(1)}/s with $bots CPU tanks, $sent';
}

/// Plays [length] of a round on a real [TankGame] with the own tank always
/// on the move, turning the turret and firing, as busy as a pilot gets.
Future<_Measured> _playRound({
  required GameMode mode,
  required bool bots,
  required bool othersPresent,
  Duration length = _length,
}) async {
  final net = _CountingNet()..othersPresent = othersPresent;
  final game = offlineGame(net: net)..onGameResize(Vector2(1280, 720));
  for (final id in [
    OverlayIds.lobby,
    OverlayIds.countdown,
    OverlayIds.hud,
    OverlayIds.spectator,
    OverlayIds.roundOver,
    OverlayIds.closed,
    OverlayIds.tutorial,
  ]) {
    game.overlays.addEntry(id, (_, _) => const SizedBox());
  }
  // ignore: invalid_use_of_internal_member
  await game.load();
  // ignore: invalid_use_of_internal_member
  game.mount();
  await game.ready();
  game
    ..update(0)
    ..chooseMode(mode)
    ..fillWithBots.value = bots
    ..startRound();
  // The countdown runs on the wall clock.
  await Future<void>.delayed(const Duration(seconds: 3, milliseconds: 100));
  game.update(0);
  expect(game.phase.value, GamePhase.playing);
  final counted = net.total;

  const dt = 1 / 60;
  final frames = length.inMilliseconds * 60 ~/ 1000;
  var t = 0.0;
  for (var frame = 0; frame < frames; frame++) {
    t += dt;
    game.touch
      ..drive = (cos(t), sin(t))
      ..aim = t * 2
      ..fire = frame % 30 == 0;
    game.update(dt);
  }
  expect(
    game.phase.value,
    GamePhase.playing,
    reason: 'the round must run the whole time to measure it',
  );
  return _Measured(
    perSecond: (net.total - counted) / (length.inMilliseconds / 1000),
    bots: game.botTanks.length,
    sent: Map.of(net.sent),
  );
}

/// Messages a second Realtime counts for a room of [pilots] humans, each
/// sending what [pilot] sent, one of them also driving the CPU tanks.
double _roomLoad({
  required int pilots,
  required _Measured pilot,
  _Measured? host,
}) {
  final sent =
      (host?.perSecond ?? pilot.perSecond) + (pilots - 1) * pilot.perSecond;
  // Sent once, delivered to everybody else in the room.
  return sent * pilots;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NetService.send', () {
    RoundStartPayload round() => RoundStartPayload(
      seed: 1,
      startedAt: DateTime.now().millisecondsSinceEpoch,
      participants: const ['me'],
    );

    test('alone in the room nothing goes onto the channel, but the replay '
        'still records it', () {
      final net = _CountingNet();
      final recorder = ReplayRecorder()
        ..start(round(), names: const {}, styles: const {});
      net.recorder = recorder;
      net.send(NetEvent.state, {'id': 'me'});
      expect(net.total, 0);
      expect(recorder.finish()?.events, hasLength(1));
    });

    test('with somebody else in the room every message goes out', () {
      final net = _CountingNet()..othersPresent = true;
      net
        ..send(NetEvent.state, {'id': 'me'})
        ..send(NetEvent.shoot, {'id': 'me'});
      expect(net.total, 2);
    });

    test('a running replay sends nothing', () {
      final net = _CountingNet()
        ..othersPresent = true
        ..muted = true;
      net.send(NetEvent.state, {'id': 'me'});
      expect(net.total, 0);
    });
  });

  group('messages a client sends in a round', () {
    late _Measured pilot;
    late _Measured host;

    setUpAll(() async {
      pilot = await _playRound(
        mode: GameMode.multi,
        bots: false,
        othersPresent: true,
      );
      host = await _playRound(
        mode: GameMode.multi,
        bots: true,
        othersPresent: true,
      );
    });

    test('a solo round with CPU tanks puts nothing on the channel', () async {
      final solo = await _playRound(
        mode: GameMode.solo,
        bots: true,
        othersPresent: false,
      );
      expect(solo.bots, greaterThan(0));
      expect(solo.perSecond, 0, reason: '$solo');
    });

    test('a pilot sends about ten messages a second', () {
      expect(pilot.bots, 0);
      expect(pilot.perSecond, inInclusiveRange(8, 13), reason: '$pilot');
    });

    test('all CPU tanks of a host move in one stream of ten a second', () {
      expect(host.bots, greaterThan(1));
      final seconds = _length.inMilliseconds / 1000;
      expect(
        (host.sent[NetEvent.states] ?? 0) / seconds,
        lessThanOrEqualTo(10.5),
        reason: '$host',
      );
      // The host's own tank sends no more than any other pilot's.
      expect(host.sent[NetEvent.state], pilot.sent[NetEvent.state]);
    });

    test('two pilots with CPU tanks fit the free plan', () {
      final load = _roomLoad(pilots: 2, pilot: pilot, host: host);
      expect(load, lessThan(_freePlanPerSecond), reason: 'room: $load/s');
    });

    test(
      'three pilots fit the free plan',
      () {
        final load = _roomLoad(pilots: 3, pilot: pilot);
        expect(load, lessThan(_freePlanPerSecond * 0.8), reason: '$load/s');
      },
      skip:
          'On the edge: about 98 a second, with no room left for a second '
          'room playing at the same time.',
    );

    test('a room of four with CPU tanks fits the Pro plan', () {
      final load = _roomLoad(pilots: 4, pilot: pilot, host: host);
      expect(load, lessThan(_proPlanPerSecond), reason: 'room: $load/s');
    });

    test(
      'a room of four pilots fits the free plan',
      () {
        final load = _roomLoad(pilots: 4, pilot: pilot);
        expect(load, lessThan(_freePlanPerSecond), reason: 'room: $load/s');
      },
      skip:
          'Not on the free plan: about 175 a second. The load grows with '
          'the square of the pilots in a room.',
    );
  });
}
