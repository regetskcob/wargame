import 'package:flutter_watchos/flutter_watchos.dart';

import 'watch/watch_support.dart';
import 'watch/wear_crown.dart';
import 'watch/wear_haptics.dart';

/// Taps the wrist: the Taptic Engine on the Apple Watch, the vibration motor
/// on Wear OS. Does nothing anywhere else, and the Apple Watch Simulator has
/// no engine.
class Haptics {
  /// Shakes come in bursts; one tap per burst is enough.
  static const _minGap = Duration(milliseconds: 150);
  static DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  /// The screen shakes by [strength]: own tank hit, or a blast close by. A
  /// small shake is a click, a heavy one a notification.
  static void shake(double strength) {
    if (!onWatch || strength < 1) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(_last) < _minGap) {
      return;
    }
    _last = now;
    _play(strength >= 8 ? WatchHapticType.notification : WatchHapticType.click);
  }

  /// One second of the countdown.
  static void tick() => _play(WatchHapticType.click);

  /// The round starts.
  static void go() => _play(WatchHapticType.start);

  /// The own tank is destroyed.
  static void destroyed() => _play(WatchHapticType.failure);

  /// The round ends.
  static void roundOver({required bool won}) =>
      _play(won ? WatchHapticType.success : WatchHapticType.failure);

  static void _play(WatchHapticType type) {
    if (FlutterWatchosPlatform.isWatch) {
      WatchHaptics.play(type);
    } else if (onWear) {
      WearHaptics.play(type);
    }
  }
}
