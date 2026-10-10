import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_watchos/flutter_watchos.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tv/tv_input.dart';
import 'watch/wear_crown.dart';
import 'watch/wear_haptics.dart';

const _onKey = 'panzergefecht.haptics';

/// Felt feedback: the Taptic Engine on the Apple Watch and the iPhone, the
/// vibration motor on Android phones and Wear OS watches. iPads and most
/// Android tablets have no motor, the calls then pass without effect. Web,
/// Mac and Apple TV stay still.
class Haptics {
  /// Whether the player wants to feel the game. Phones only, the watch always
  /// taps the wrist since it is played without looking.
  static final on = ValueNotifier<bool>(true);

  /// Shakes come in bursts; one tap per burst is enough.
  static const _minGap = Duration(milliseconds: 150);
  static DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  /// Whether this device is a phone or tablet with a motor to drive.
  static bool get onPhone =>
      !kIsWeb &&
      !onTv &&
      !FlutterWatchosPlatform.isWatch &&
      !onWear &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  static Future<void> init() async {
    try {
      on.value = await SharedPreferencesAsync().getBool(_onKey) ?? true;
    } on Object {
      // Without a store vibration stays on.
    }
  }

  static Future<void> set({required bool value}) async {
    on.value = value;
    if (value) {
      // A tap to show what the switch does.
      unawaited(HapticFeedback.mediumImpact());
    }
    try {
      await SharedPreferencesAsync().setBool(_onKey, value);
    } on Object {
      // The choice then only lasts until the game is closed.
    }
  }

  /// The screen shakes by [strength]: own tank hit, or a blast close by. A
  /// small shake is a light tap, a heavy one a hard knock.
  static void shake(double strength) {
    if (strength < 1) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(_last) < _minGap) {
      return;
    }
    _last = now;
    final heavy = strength >= 8;
    _play(
      watch: heavy ? WatchHapticType.notification : WatchHapticType.click,
      phone: heavy ? HapticFeedback.heavyImpact : HapticFeedback.lightImpact,
    );
  }

  /// One second of the countdown.
  static void tick() =>
      _play(watch: WatchHapticType.click, phone: HapticFeedback.selectionClick);

  /// The round starts.
  static void go() =>
      _play(watch: WatchHapticType.start, phone: HapticFeedback.mediumImpact);

  /// The own tank is destroyed.
  static void destroyed() =>
      _play(watch: WatchHapticType.failure, phone: HapticFeedback.heavyImpact);

  /// The round ends.
  static void roundOver({required bool won}) => _play(
    watch: won ? WatchHapticType.success : WatchHapticType.failure,
    phone: HapticFeedback.heavyImpact,
  );

  /// A tap outside the round, like a button on the phone controller.
  static void feel(Future<void> Function() phone) {
    if (on.value && onPhone) {
      unawaited(phone());
    }
  }

  static void _play({
    required WatchHapticType watch,
    required Future<void> Function() phone,
  }) {
    if (FlutterWatchosPlatform.isWatch) {
      WatchHaptics.play(watch);
    } else if (onWear) {
      // A pattern of its own for each moment, as on the Apple Watch.
      WearHaptics.play(watch);
    } else {
      feel(phone);
    }
  }
}
