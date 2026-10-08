import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/net/pad_link.dart';

/// A phone paired as controller talks to the screen on a channel of its
/// own, and every message there counts twice against the project's
/// Realtime limit (100 a second on the free plan): once sent, once
/// delivered. Before the throttle a pair cost up to 60 a second.
const _seconds = 10;

/// Plays [_seconds] of a phone whose sticks [move] sets every tick, and
/// returns what it sent.
List<Map<String, dynamic>> _phone(
  void Function(PadRemote remote, Duration at) move,
) {
  final sent = <Map<String, dynamic>>[];
  fakeAsync((async) {
    final remote = PadRemote('ABCDEFGH')
      ..screenOnline.value = true
      ..onSend = (event, payload, lane) {
        if (event == 'pad') {
          sent.add(payload);
        }
      };
    var at = Duration.zero;
    while (at < const Duration(seconds: _seconds)) {
      move(remote, at);
      remote.tick();
      async.elapse(PadRemote.tickInterval);
      at += PadRemote.tickInterval;
    }
  });
  return sent;
}

/// How often the screen tells the phone about the tank when the status
/// changes with every tick, as in a heavy fight.
double _statusPerSecond({required bool changing}) {
  var sent = 0;
  fakeAsync((async) {
    final gate = SendGate(
      gap: PadScreen.statusGap,
      keepalive: PadScreen.statusKeepalive,
    );
    var at = Duration.zero;
    var step = 0;
    while (at < const Duration(seconds: _seconds)) {
      if (gate.shouldSend(changing ? 'hp ${step++}' : 'hp 1')) {
        sent++;
      }
      async.elapse(PadScreen.tickInterval);
      at += PadScreen.tickInterval;
    }
  });
  return sent / _seconds;
}

void main() {
  final random = Random(7);

  /// A thumb sweeping the drive stick round and turning the turret.
  void sweeping(PadRemote remote, Duration at) {
    final t = at.inMilliseconds / 1000;
    remote.input
      ..drive = (cos(t * 3), sin(t * 3))
      ..aim = t * 2
      ..aimHeld = true;
  }

  /// A thumb holding the sticks still, with a tremor below half a rounding
  /// step: a fiftieth of the drive stick, a third of a degree of aim.
  void resting(PadRemote remote, Duration at) {
    double tremor(double size) => (random.nextDouble() - 0.5) * 2 * size;
    remote.input
      ..drive = (0.5 + tremor(0.02), -0.25 + tremor(0.02))
      ..aim = 1 + tremor(0.006);
  }

  test('a moving thumb goes out at most twelve and a half times a second, '
      'and at least ten', () {
    final perSecond = _phone(sweeping).length / _seconds;
    expect(perSecond, inInclusiveRange(10, 12.5));
  });

  test('a resting thumb only says it is there, a few times a second', () {
    final sent = _phone(resting);
    expect(sent.length / _seconds, lessThanOrEqualTo(3.5));
    expect({for (final pad in sent) pad['d'].toString()}, hasLength(1));
  });

  test('letting go of the stick arrives', () {
    final sent = _phone((remote, at) {
      if (at < const Duration(seconds: 2)) {
        sweeping(remote, at);
      } else {
        remote.input
          ..drive = null
          ..aimHeld = false;
      }
    });
    expect(sent.last.containsKey('d'), isFalse);
    expect(sent.last['h'], isFalse);
  });

  test('the sticks are rounded to sixteenths', () {
    final sent = _phone((remote, _) => remote.input.drive = (0.61, -0.79));
    expect(sent.first['d'], [0.625, -0.8125]);
  });

  test('the status goes out about four times a second in a fight, '
      'once a second at rest', () {
    expect(_statusPerSecond(changing: true), lessThanOrEqualTo(4));
    expect(_statusPerSecond(changing: false), lessThanOrEqualTo(1));
  });

  test('a duel with two phones on their own lanes costs two pairs, not '
      'three ends on one channel', () {
    final phone = _phone(sweeping).length / _seconds;
    final status = _statusPerSecond(changing: true);
    // Each lane: the phone and the screen, sent once and delivered once.
    final lanes = 2 * (phone + status) * 2;
    // One shared channel: every message reached both other ends.
    final shared = (2 * phone + 2 * status) * 3;
    expect(lanes, lessThanOrEqualTo(65), reason: '$lanes/s');
    expect(shared, greaterThan(90), reason: '$shared/s');
  });

  test('a pair of phone and screen costs at most 35 messages a second', () {
    final phone = _phone(sweeping).length / _seconds;
    final status = _statusPerSecond(changing: true);
    // Sent once and delivered once.
    final load = (phone + status) * 2;
    expect(load, lessThanOrEqualTo(35), reason: '$load/s');
  });
}
