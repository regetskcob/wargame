import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/ui/widgets/tablet_scale.dart';

void main() {
  testWidgets(
    'a phone-sized screen counts as a phone, a small Mac window not',
    (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      expect(deviceIsPhone, isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(deviceIsPhone, isFalse);
      debugDefaultTargetPlatformOverride = null;
      tester.view.physicalSize = const Size(1024, 1366);
      expect(deviceIsPhone, isFalse);
    },
  );
}
