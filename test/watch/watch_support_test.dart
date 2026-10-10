import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/touch_input.dart';
import 'package:wargame/src/watch/watch_support.dart';
import 'package:wargame/src/watch/wear_crown.dart';

void main() {
  // The Digital Crown: raw crown distance in, heading out.
  double steer(double heading, double crown, double tankAngle) =>
      WatchSteering.steer(heading, WatchSteering.crownTurnOf(crown), tankAngle);

  test('one detent is a small correction', () {
    final heading = steer(0, 0.75, 0);
    expect(heading, greaterThan(0));
    expect(heading, lessThan(0.05));
    expect(steer(0, -0.75, 0), closeTo(-heading, 1e-9));
  });

  test('a calm turn leads by more than a detent, a flick no more than the '
      'leash', () {
    expect(steer(0, 20, 0), greaterThan(steer(0, 0.75, 0) * 4));
    expect(steer(0, 2000, 0), WatchSteering.maxLead);
    expect(steer(0, -2000, 0), -WatchSteering.maxLead);
  });

  test('the heading never runs away from the hull', () {
    var heading = 0.0;
    for (var i = 0; i < 100; i++) {
      heading = steer(heading, 500, 0);
    }
    expect(heading, WatchSteering.maxLead);
  });

  test('a turn to the right never makes the tank turn left', () {
    // A tank facing anywhere, even across the seam at pi: turning the crown
    // forward puts the heading to its right.
    for (final angle in [0.0, 3.0, pi, -3.1, 10.0]) {
      final lead = steer(angle, 5000, angle) - angle;
      expect(lead, closeTo(WatchSteering.maxLead, 1e-9));
    }
  });

  test('the heading stays put without crown', () {
    expect(steer(0.2, 0, 0), closeTo(0.2, 1e-9));
  });

  group('Wear OS', () {
    tearDown(() {
      onWearForTesting = false;
      while (WearCrown.instance.enabled) {
        WearCrown.instance.disable();
      }
      WearCrown.instance.drain();
    });

    test('a click of the bezel turns the heading as far as the bezel', () {
      expect(
        WatchSteering.steer(
          0,
          WatchSteering.bezelTurnOf(1),
          0,
          lead: WatchSteering.bezelMaxLead,
        ),
        closeTo(pi / 12, 1e-9),
      );
      // A quarter turn of the bezel asks for a quarter turn of the tank.
      expect(
        WatchSteering.steer(
          0,
          WatchSteering.bezelTurnOf(6),
          0,
          lead: WatchSteering.bezelMaxLead,
        ),
        closeTo(pi / 2, 1e-9),
      );
    });

    test('a whole turn of the bezel never makes the tank turn back', () {
      final heading = WatchSteering.steer(
        0,
        WatchSteering.bezelTurnOf(24),
        0,
        lead: WatchSteering.bezelMaxLead,
      );
      expect(heading, WatchSteering.bezelMaxLead);
    });

    test('the bezel steers the tank during a round and scrolls after', () {
      onWearForTesting = true;
      expect(onWatch, isTrue);
      final input = TouchInput();
      final steering = WatchSteering(input);
      final tank = Object();
      void frame({bool playing = true}) => steering.update(
        playing: playing,
        tank: tank,
        tankAngle: 0,
        hard: false,
      );

      frame();
      expect(WearCrown.instance.enabled, isTrue);
      expect(input.drive!.$1, closeTo(0, 1e-9));
      WearCrown.instance.receive(2, 0);
      frame();
      // Two clicks clockwise: 30 degrees to the right of north.
      expect(input.drive!.$1, closeTo(sin(pi / 6), 1e-9));
      expect(input.drive!.$2, closeTo(-cos(pi / 6), 1e-9));
      expect(input.assist, isTrue);

      frame(playing: false);
      expect(WearCrown.instance.enabled, isFalse);
      expect(input.drive, isNull);
    });
  });
}
