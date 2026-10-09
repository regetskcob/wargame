import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/watch/watch_support.dart';

void main() {
  const steer = WatchSteering.steer;

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
}
