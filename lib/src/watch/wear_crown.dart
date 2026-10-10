import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Whether this is a Wear OS watch, as found by [detectWear] before the game
/// starts. Always false elsewhere.
bool get onWear => _onWear;
bool _onWear = false;

/// Whether the Wear OS watch has a round screen.
bool get wearRound => _wearRound;
bool _wearRound = false;

@visibleForTesting
set onWearForTesting(bool value) => _onWear = value;

@visibleForTesting
set wearRoundForTesting(bool value) => _wearRound = value;

/// Asks Android whether it runs on a watch, and if so starts listening to
/// its crown. Call once before the game starts: [onWear] picks the screens.
Future<void> detectWear() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }
  try {
    final info = await const MethodChannel('wargame/wear')
        .invokeMapMethod<String, Object?>('info');
    _onWear = info?['watch'] == true;
    _wearRound = info?['round'] == true;
  } on Object {
    // An older native side without the plugin: a phone, as before.
    _onWear = false;
  }
  if (_onWear) {
    WearCrown.instance.start();
  }
}

/// The rotating crown or bezel of a Wear OS watch, the counterpart of
/// `WatchCrown` from flutter_watchos on the Apple Watch.
///
/// Flutter on Android drops the turns, so `WearPlugin.kt` streams them in.
/// Between rounds they scroll whatever list sits in the middle of the
/// screen, as the system would. While a round runs ([enable]) they are kept
/// as raw detents for the steering instead.
class WearCrown {
  WearCrown._();

  static final instance = WearCrown._();

  static const _events = EventChannel('wargame/crown');

  /// Pointer id of the scroll events made up from the crown, out of the way
  /// of real fingers.
  static const _device = 0x7e41;

  StreamSubscription<Object?>? _sub;
  var _enabled = 0;
  var _detents = 0.0;

  void start() {
    _sub ??= _events.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        receive(
          (event['detents'] as num?)?.toDouble() ?? 0,
          (event['pixels'] as num?)?.toDouble() ?? 0,
        );
      }
    }, onError: (Object _) {});
  }

  /// Whether the crown steers right now instead of scrolling.
  bool get enabled => _enabled > 0;

  /// Takes the crown for raw input. Counted, like `WatchCrown.enable`.
  void enable() => _enabled++;

  /// Hands the crown back to the lists once every [enable] is matched.
  void disable() {
    if (_enabled > 0) {
      _enabled--;
    }
  }

  /// Detents turned since the last call, forward positive. A Galaxy bezel
  /// reports one per click of 15 degrees.
  double drain() {
    final detents = _detents;
    _detents = 0;
    return detents;
  }

  /// One turn from the native side: [detents] for steering, [pixels] as
  /// far as the system would scroll a list for it.
  @visibleForTesting
  void receive(double detents, double pixels) {
    if (enabled) {
      _detents += detents;
      return;
    }
    _detents = 0;
    _scroll(pixels);
  }

  void _scroll(double pixels) {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty || pixels == 0) {
      return;
    }
    final view = views.first;
    final size = view.physicalSize / view.devicePixelRatio;
    GestureBinding.instance.handlePointerEvent(
      PointerScrollEvent(
        viewId: view.viewId,
        device: _device,
        position: size.center(Offset.zero),
        scrollDelta: Offset(0, pixels),
      ),
    );
  }
}
