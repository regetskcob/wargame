import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_watchos/flutter_watchos.dart';

/// Taps the wrist of a Wear OS watch, the counterpart of `WatchHaptics` on
/// the Apple Watch. `WearPlugin.kt` plays each [WatchHapticType] as a
/// vibration of its own.
class WearHaptics {
  static const _channel = MethodChannel('wargame/wear');

  static void play(WatchHapticType type) {
    unawaited(
      _channel
          .invokeMethod<bool>('vibrate', type.name)
          .catchError((Object _) => false),
    );
  }
}
