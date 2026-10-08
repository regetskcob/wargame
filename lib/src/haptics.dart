import 'package:flutter_watchos/flutter_watchos.dart';

/// Taptic Engine feedback on the Apple Watch. Does nothing anywhere else:
/// `WatchHaptics` is a no-op off the watch, and the Simulator has no engine.
class Haptics {
  /// Shakes come in bursts; one tap per burst is enough.
  static const _minGap = Duration(milliseconds: 150);
  static DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  /// The screen shakes by [strength]: own tank hit, or a blast close by. A
  /// small shake is a click, a heavy one a notification.
  static void shake(double strength) {
    if (!FlutterWatchosPlatform.isWatch || strength < 1) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(_last) < _minGap) {
      return;
    }
    _last = now;
    WatchHaptics.play(
      strength >= 8 ? WatchHapticType.notification : WatchHapticType.click,
    );
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
    }
  }
}
