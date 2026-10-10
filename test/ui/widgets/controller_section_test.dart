import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
