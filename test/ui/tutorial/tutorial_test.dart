import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/net/room.dart';
import 'package:wargame/src/ui/tutorial/demo_painter.dart';
import 'package:wargame/src/ui/tutorial/tutorial_overlay.dart';
import 'package:wargame/src/ui/tutorial/tutorial_steps.dart';
import 'package:wargame/src/vision/vision_support.dart';

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

  Finder onCard(String text) => find.descendant(
    of: find.byKey(TutorialOverlay.cardKey),
    matching: find.text(text),
  );

  DemoPainter painter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((p) => p.painter)
      .whereType<DemoPainter>()
      .single;

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

  test('a Vision Pro explains looking and pinching with the same scenes', () {
    final touch = tutorialSteps(touch: true);
    onVisionForTesting = true;
    addTearDown(() => onVisionForTesting = false);
    final vision = tutorialSteps(touch: true);
    expect(vision.map((s) => s.scene), touch.map((s) => s.scene));
    expect(vision.first.text, contains('Zeigefinger'));
    expect(vision[1].text, contains('hinsiehst'));
    expect(
      vision.take(controlSteps(touch: true)).map((s) => s.text),
      everyElement(isNot(contains('Stick'))),
    );
  });

  testWidgets('walks through every card and closes at the end', (tester) async {
    final closed = await pump(tester, touch: true);
    final steps = tutorialSteps(touch: true);
    for (final step in steps.take(steps.length - 1)) {
      expect(onCard(step.title), findsOneWidget);
      await next(tester);
    }
    expect(onCard(steps.last.title), findsOneWidget);
    expect(closed, isEmpty);
    await tester.tap(find.text("LOS GEHT'S"));
    await tester.pump();
    expect(closed, hasLength(1));
  });

  testWidgets('each device gets its own controls', (tester) async {
    await pump(tester, touch: true);
    expect(find.textContaining('STEUERUNG TOUCH'), findsOneWidget);
    expect(onCard('ZIELHILFE'), findsNothing);
    expect(onCard('FAHREN'), findsOneWidget);
    await pump(tester, touch: false);
    expect(find.textContaining('STEUERUNG TASTATUR & MAUS'), findsOneWidget);
    expect(onCard('FAHREN'), findsOneWidget);
  });

  testWidgets('the quick tour plays on by itself', (tester) async {
    await pump(tester, touch: false);
    for (var i = 0; i < controlSteps(touch: false); i++) {
      await next(tester);
    }
    final tour = tutorialSteps(touch: false)[controlSteps(touch: false)];
    expect(onCard(tour.title), findsOneWidget);
    expect(find.text(tour.chips.first.label), findsOneWidget);
    await tester.pump(TutorialOverlay.tourCard);
    await tester.pump(const Duration(milliseconds: 300));
    expect(onCard(tour.title), findsNothing);
  });

  testWidgets('keys step through and escape skips', (tester) async {
    final closed = await pump(tester, touch: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(onCard('ZIELEN'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(onCard('FAHREN'), findsOneWidget);
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
      final card = tester.getSize(find.byKey(TutorialOverlay.cardKey));
      final steps = tutorialSteps(touch: true);
      for (var i = 1; i < steps.length; i++) {
        await tester.tap(find.text('WEITER'));
        await tester.pump(const Duration(milliseconds: 300));
        final button = i == steps.length - 1 ? "LOS GEHT'S" : 'WEITER';
        expect(tester.getCenter(find.text(button)), weiter, reason: '$i');
        expect(tester.getSize(find.byKey(TutorialOverlay.cardKey)), card);
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

  testWidgets('a controls card moves on by itself while nobody takes over', (
    tester,
  ) async {
    await pump(tester, touch: true);
    expect(onCard('FAHREN'), findsOneWidget);
    await tester.pump(TutorialOverlay.controlsCard);
    await tester.pump(const Duration(milliseconds: 300));
    expect(onCard('ZIELEN'), findsOneWidget);
  });

  testWidgets('a thumb on the stick takes over and the card waits', (
    tester,
  ) async {
    await pump(tester, touch: true);
    expect(painter(tester).practice, isNull);
    expect(painter(tester).invite, isTrue);
    final gesture = await tester.startGesture(const Offset(120, 620));
    await tester.pump();
    final practice = painter(tester).practice!;
    final start = practice.pos;
    expect(find.textContaining('DU STEUERST'), findsOneWidget);
    // Push the stick to the right and hold it there.
    await gesture.moveBy(const Offset(60, 0));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(practice.pos.dx, greaterThan(start.dx));
    // Long past the card's time it still waits for WEITER.
    await tester.pump(TutorialOverlay.controlsCard * 2);
    expect(onCard('FAHREN'), findsOneWidget);
    await gesture.up();
    await next(tester);
    expect(onCard('ZIELEN'), findsOneWidget);
    expect(painter(tester).practice, isNull);
  });

  testWidgets('a game key takes over on a computer, the arrows then drive', (
    tester,
  ) async {
    await pump(tester, touch: false);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    await tester.pump();
    final practice = painter(tester).practice!;
    final start = practice.pos;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    expect(practice.pos.dy, lessThan(start.dy));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(onCard('FAHREN'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(onCard('ZIELEN'), findsOneWidget);
    expect(painter(tester).practice, isNull);
  });

  testWidgets('the quick tour offers no training ground', (tester) async {
    await pump(tester, touch: false);
    for (var i = 0; i < controlSteps(touch: false); i++) {
      await next(tester);
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    expect(painter(tester).practice, isNull);
    expect(painter(tester).invite, isFalse);
  });
}
