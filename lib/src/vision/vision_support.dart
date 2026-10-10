import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../tv/tv_input.dart';

/// Whether the iPad app runs on an Apple Vision Pro, as found by
/// [detectVision] before the game starts. Always false elsewhere.
///
/// Flutter has no visionOS build, so the game runs there as a compatible
/// iPad app in a window: a pinch is a tap where the player looks. The round
/// then aims where the eyes go and keeps the window still.
bool get onVision => _onVision;
bool _onVision = false;

@visibleForTesting
set onVisionForTesting(bool value) => _onVision = value;

/// Asks iOS whether the app runs on visionOS. Call once before the game
/// starts.
Future<void> detectVision() async {
  if (kIsWeb || onTv || defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  try {
    _onVision =
        await const MethodChannel('wargame/tv').invokeMethod<bool>('vision') ??
        false;
  } on Object {
    // An older native side without the question: an iPhone or iPad.
    _onVision = false;
  }
}
