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

  /// Radians of heading per unit of crown rotation. One full turn of the
  /// crown is one full turn of the tank. Tune on a real watch.
  static const radiansPerCrownUnit = 2 * pi;

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
    _heading += WatchCrown.instance.drain() * radiansPerCrownUnit;
    _input
      ..drive = (sin(_heading), -cos(_heading))
      ..assist = true
      ..fire = hard;
  }
}
