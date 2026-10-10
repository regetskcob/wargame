import 'dart:math';

import 'package:flutter_watchos/flutter_watchos.dart';

import '../game/touch_input.dart';
import 'wear_crown.dart';

/// Whether this is a watch: the Apple Watch build or a Wear OS watch. Both
/// get the watch screens and the crown steering. Always false elsewhere.
bool get onWatch => FlutterWatchosPlatform.isWatch || onWear;

/// Whether the watch screen is round, as most Wear OS watches are. The
/// screens then keep to the circle: gauges along the rim, menus inside the
/// largest square. The Apple Watch is a rounded rectangle.
bool get watchRound => onWear && wearRound;

/// Steers the tank with the crown: the Digital Crown on the Apple Watch, the
/// rotating crown or bezel on Wear OS. The tank drives all the time and
/// fires by itself at the nearest enemy (the touch aim assist), so the crown
/// only picks the direction: turn it clockwise to head right.
///
/// The crown scrolls the menus as usual. Only while a round runs it is taken
/// as raw input, and handed back afterwards.
class WatchSteering {
  WatchSteering(this._input);

  /// The Digital Crown reports scroll distance with the system's
  /// acceleration on top: about 0.75 for one detent, tens per frame for a
  /// calm turn and thousands for a flick. Taken linearly, one detent swung
  /// the heading round by most of a circle. A logarithm keeps a detent a
  /// small correction of about two degrees and a flick no worse than a quick
  /// turn.
  static const crownTurn = 0.06;

  /// Wear OS reports plain detents without acceleration: a Galaxy bezel
  /// clicks 24 times a full turn. With the Apple Watch's two degrees a
  /// whole turn of the bezel moved the heading by less than 60 degrees, so
  /// a detent turns the heading as far as the bezel itself turned.
  static const bezelTurn = pi / 12;

  /// The heading runs at most this far ahead of the hull (radians). Past
  /// about 0.4 the tank already turns at full speed, so more lead only
  /// makes it overshoot once the crown stops, and a lead beyond half a
  /// circle made it turn the wrong way round.
  static const maxLead = 0.45;

  /// A bezel turns in deliberate clicks rather than a stream, and turning it
  /// a quarter should turn the tank a quarter, even when the hand was
  /// quicker than the hull. So on Wear OS the heading may run further ahead,
  /// still short of half a circle.
  static const bezelMaxLead = 3 * pi / 4;

  /// How far one frame of Digital Crown rotation turns the heading
  /// (radians).
  static double crownTurnOf(double crown) =>
      crown.sign * crownTurn * log(1 + crown.abs());

  /// How far [detents] of a Wear OS crown or bezel turn the heading
  /// (radians).
  static double bezelTurnOf(double detents) => detents * bezelTurn;

  /// The heading after turning it by [turn] radians, for a tank facing
  /// [tankAngle], at most [lead] ahead of it.
  static double steer(
    double heading,
    double turn,
    double tankAngle, {
    double lead = maxLead,
  }) {
    // Only the lead so far is wrapped, the turn adds on top: a quick spin
    // of the bezel past half a circle must not come out as a turn the other
    // way.
    final ahead =
        atan2(sin(heading - tankAngle), cos(heading - tankAngle)) + turn;
    return tankAngle + ahead.clamp(-lead, lead);
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
        _disableCrown();
        _input
          ..drive = null
          ..assist = false
          ..fire = false;
      }
      return;
    }
    if (!_active) {
      _active = true;
      _enableCrown();
      _drainTurn();
    }
    if (!identical(tank, _tank)) {
      // A new tank, after a respawn: start in the direction it faces.
      _tank = tank;
      _heading = tankAngle;
    }
    _heading = steer(
      _heading,
      _drainTurn(),
      tankAngle,
      lead: onWear ? bezelMaxLead : maxLead,
    );
    _input
      ..drive = (sin(_heading), -cos(_heading))
      ..assist = true
      ..fire = hard;
  }

  void _enableCrown() =>
      onWear ? WearCrown.instance.enable() : WatchCrown.instance.enable();

  void _disableCrown() =>
      onWear ? WearCrown.instance.disable() : WatchCrown.instance.disable();

  double _drainTurn() => onWear
      ? bezelTurnOf(WearCrown.instance.drain())
      : crownTurnOf(WatchCrown.instance.drain());
}
