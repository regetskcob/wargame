import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/tv/tv_input.dart';

void main() {
  test('the Apple Watch never opens the gamepad channel', () {
    // The watch build reports iOS; it has no gamepad plugin, and listening
    // threw a MissingPluginException on every start (release test 1.7.0).
    expect(
      padsSupportedOn(
        tv: false,
        web: false,
        platform: TargetPlatform.iOS,
        appleWatch: true,
      ),
      isFalse,
    );
  });

  test('phones, tablets, Macs, televisions and browsers read controllers', () {
    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.macOS,
    ]) {
      expect(
        padsSupportedOn(
          tv: false,
          web: false,
          platform: platform,
          appleWatch: false,
        ),
        isTrue,
        reason: '$platform',
      );
    }
    expect(
      padsSupportedOn(
        tv: true,
        web: false,
        platform: TargetPlatform.iOS,
        appleWatch: false,
      ),
      isTrue,
    );
    expect(
      padsSupportedOn(
        tv: false,
        web: true,
        platform: TargetPlatform.linux,
        appleWatch: false,
      ),
      isTrue,
    );
    expect(
      padsSupportedOn(
        tv: false,
        web: false,
        platform: TargetPlatform.windows,
        appleWatch: false,
      ),
      isFalse,
    );
  });
}
