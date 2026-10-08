import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/net/room.dart';
import 'package:wargame/src/ui/tutorial/tutorial_overlay.dart';
import 'package:wargame/src/ui/tutorial/tutorial_steps.dart';

void main() {
  Future<List<int>> pump(
    WidgetTester tester, {
    required bool touch,
    Size size = const Size(1280, 720),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final closed = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: TutorialOverlay(
          key: UniqueKey(),
          touch: touch,
          onClose: () => closed.add(1),
        ),
      ),
    );
    await tester.pump();
    return closed;
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text('WEITER'));
    await tester.pump(const Duration(milliseconds: 300));
  }

  test('touch and keyboard explain their own controls, then share the '
      'tour', () {
    final touch = tutorialSteps(touch: true);
    final keys = tutorialSteps(touch: false);
    expect(touch.first.text, contains('Daumen'));
    expect(keys.first.text, contains('W fährt'));
    expect(
      touch.take(controlSteps(touch: true)).map((s) => s.scene),
      contains(DemoScene.assist),
    );
    expect(
      keys.take(controlSteps(touch: false)).map((s) => s.scene),
      isNot(contains(DemoScene.assist)),
    );
    expect(
      touch.skip(controlSteps(touch: true)).map((s) => s.title),
      keys.skip(controlSteps(touch: false)).map((s) => s.title),
    );
    expect(touch.last.scene, DemoScene.ready);
  });

  testWidgets('walks through every card and closes at the end', (tester) async {
    final closed = await pump(tester, touch: true);
    final steps = tutorialSteps(touch: true);
    for (final step in steps.take(steps.length - 1)) {
      expect(find.text(step.title), findsOneWidget);
      await next(tester);
    }
    expect(find.text(steps.last.title), findsOneWidget);
    expect(closed, isEmpty);
    await tester.tap(find.text("LOS GEHT'S"));
    await tester.pump();
    expect(closed, hasLength(1));
  });

  testWidgets('each device gets its own controls', (tester) async {
    await pump(tester, touch: true);
    expect(find.textContaining('STEUERUNG TOUCH'), findsOneWidget);
    expect(find.text('ZIELHILFE'), findsNothing);
    expect(find.text('FAHREN'), findsOneWidget);
    await pump(tester, touch: false);
    expect(find.textContaining('STEUERUNG TASTATUR & MAUS'), findsOneWidget);
    expect(find.text('FAHREN'), findsOneWidget);
  });

  testWidgets('the quick tour plays on by itself', (tester) async {
    await pump(tester, touch: false);
    for (var i = 0; i < controlSteps(touch: false); i++) {
      await next(tester);
    }
    final tour = tutorialSteps(touch: false)[controlSteps(touch: false)];
    expect(find.text(tour.title), findsOneWidget);
    expect(find.text(tour.chips.first.label), findsOneWidget);
    await tester.pump(TutorialOverlay.tourCard);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(tour.title), findsNothing);
  });

  testWidgets('keys step through and escape skips', (tester) async {
    final closed = await pump(tester, touch: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('ZIELEN'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text('FAHREN'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(closed, hasLength(1));
  });

  testWidgets('every scene paints on a small phone in landscape', (
    tester,
  ) async {
    for (final touch in [true, false]) {
      await pump(tester, touch: touch, size: const Size(740, 360));
      for (var i = 0; i < tutorialSteps(touch: touch).length - 1; i++) {
        // Through one whole pass of the scene.
        for (var t = 0; t < 6; t++) {
          await tester.pump(const Duration(milliseconds: 600));
        }
        expect(tester.takeException(), isNull);
        if (find.text('WEITER').evaluate().isEmpty) {
          break;
        }
        await next(tester);
      }
    }
  });

  testWidgets('the card keeps its height and WEITER its place', (tester) async {
    for (final size in const [Size(1280, 720), Size(740, 360)]) {
      await pump(tester, touch: true, size: size);
      final weiter = tester.getCenter(find.text('WEITER'));
      final card = tester.getSize(find.byType(DecoratedBox).first);
      final steps = tutorialSteps(touch: true);
      for (var i = 1; i < steps.length; i++) {
        await tester.tap(find.text('WEITER'));
        await tester.pump(const Duration(milliseconds: 300));
        final button = i == steps.length - 1 ? "LOS GEHT'S" : 'WEITER';
        expect(tester.getCenter(find.text(button)), weiter, reason: '$i');
        expect(tester.getSize(find.byType(DecoratedBox).first), card);
      }
    }
  });

  testWidgets('skipping marks the tutorial as done like finishing', (
    tester,
  ) async {
    final closed = await pump(tester, touch: false);
    await tester.tap(find.text('ÜBERSPRINGEN'));
    await tester.pump();
    expect(closed, hasLength(1));
  });

  test('the tutorial is remembered once seen', () {
    expect(tutorialSeen(), isFalse);
    rememberTutorialSeen();
    expect(tutorialSeen(), isTrue);
  });
}
