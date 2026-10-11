import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/tv/seats.dart';
import 'package:wargame/src/ui/theme.dart';
import 'package:wargame/src/ui/widgets/pad_pairing.dart';

import '../../helpers/fakes.dart';

void main() {
  Future<void> show(WidgetTester tester, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGameTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ControllerSection(game: offlineGame()),
          ),
        ),
      ),
    );
  }

  testWidgets('a phone in the app offers itself as a controller', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await show(tester, const Size(390, 844));
    expect(find.text('ALS CONTROLLER NUTZEN'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a tablet in the app only pairs a phone, it never becomes '
      'one', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await show(tester, const Size(1180, 820));
    expect(find.text('ALS CONTROLLER NUTZEN'), findsNothing);
    expect(find.text('HANDY KOPPELN'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  // Issue 12: a phone that saw a controller offered the duel and the split
  // screen, two halves of a phone screen nobody can play on.
  testWidgets('only television, computer and tablet screens fit two halves', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final cases = {
      const Size(390, 844): false,
      const Size(844, 390): false,
      const Size(430, 932): false,
      const Size(1194, 834): true,
      const Size(1024, 1366): true,
      const Size(1280, 720): true,
    };
    for (final MapEntry(key: size, value: fits) in cases.entries) {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      expect(splitScreenFits(), fits, reason: '$size');
    }
  });
}
