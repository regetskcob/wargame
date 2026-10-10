import 'dart:math';

import 'package:flutter_watchos/flutter_watchos.dart';

import '../game/touch_input.dart';

/// Whether this is the Apple Watch build. Always false off the watch.
bool get onWatch => FlutterWatchosPlatform.isWatch;

/// Steers the tank with the Digital Crown. The tank drives all the time and
/// fires by itself at the nearest enemy (the touch aim assist), so the crown
/// only picks the direction: turn it clockwise to head right.
///
/// The crown scrolls the menus as usual. Only while a round runs it is taken
/// as raw input, and handed back afterwards.
class WatchSteering {
  WatchSteering(this._input);

  /// The crown reports scroll distance with the system's acceleration on
  /// top: about 0.75 for one detent, tens per frame for a calm turn and
  /// thousands for a flick. Taken linearly, one detent swung the heading
  /// round by most of a circle. A logarithm keeps a detent a small
  /// correction of about two degrees and a flick no worse than a quick turn.
  static const crownTurn = 0.06;

  /// The heading runs at most this far ahead of the hull (radians). Past
  /// about 0.4 the tank already turns at full speed, so more lead only
  /// makes it overshoot once the crown stops, and a lead beyond half a
  /// circle made it turn the wrong way round.
  static const maxLead = 0.45;

  /// The heading after one frame of [crown] rotation, for a tank facing
  /// [tankAngle].
  static double steer(double heading, double crown, double tankAngle) {
    final turned = heading + crown.sign * crownTurn * log(1 + crown.abs());
    final lead = atan2(sin(turned - tankAngle), cos(turned - tankAngle));
    return tankAngle + lead.clamp(-maxLead, maxLead);
  }

  final TouchInput _input;
  double _heading = 0;
  Object? _tank;
  bool _active = false;

  /// Call every frame. [tank] identifies the tank, [tankAngle] is its
  /// heading, [hard] switches off the aim assist, so the gun fires straight
  /// ahead all the time instead.
  void update({
    required bool playing,
    required Object? tank,
    required double tankAngle,
    required bool hard,
  }) {
    if (!onWatch) {
      return;
    }
    if (!playing || tank == null) {
      if (_active) {
        _active = false;
        WatchCrown.instance.disable();
        _input
          ..drive = null
          ..assist = false
          ..fire = false;
      }
      return;
    }
    if (!_active) {
      _active = true;
      WatchCrown.instance.enable();
      WatchCrown.instance.drain();
    }
    if (!identical(tank, _tank)) {
      // A new tank, after a respawn: start in the direction it faces.
      _tank = tank;
      _heading = tankAngle;
    }
    _heading = steer(_heading, WatchCrown.instance.drain(), tankAngle);
    _input
      ..drive = (sin(_heading), -cos(_heading))
      ..assist = true
      ..fire = hard;
  }
}
