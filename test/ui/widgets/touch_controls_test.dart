import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/special_weapon.dart';
import 'package:wargame/src/game/touch_input.dart';
import 'package:wargame/src/ui/widgets/touch_controls.dart';
import 'package:wargame/src/vision/vision_support.dart';

void main() {
  Future<TouchInput> pump(
    WidgetTester tester, {
    bool assist = true,
    ValueChanged<Offset>? onLook,
  }) async {
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final input = TouchInput();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TouchControls(
            input: input,
            special: ValueNotifier<(SpecialWeapon, int)?>(null),
            assist: assist,
            onLook: onLook,
          ),
        ),
      ),
    );
    return input;
  }

  testWidgets('the drive stick points where to go', (tester) async {
    final input = await pump(tester);
    final gesture = await tester.startGesture(const Offset(90, 600));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    final drive = input.drive;
    expect(drive, isNotNull);
    expect(drive!.$1, greaterThan(0.5));
    expect(drive.$2.abs(), lessThan(0.1));
    expect(input.left || input.right || input.thrust, isFalse);
    await gesture.up();
    await tester.pump();
    expect(input.drive, isNull);
  });

  testWidgets('without the assist there is no button and it stays off', (
    tester,
  ) async {
    final input = await pump(tester, assist: false);
    expect(find.text('ZIELHILFE'), findsNothing);
    expect(input.assist, isFalse);
  });

  testWidgets('aim assist starts on, the button switches it, the stick '
      'takes over while held', (tester) async {
    final input = await pump(tester);
    expect(input.assist, isTrue);
    await tester.tap(find.text('ZIELHILFE AN'));
    await tester.pump();
    expect(input.assist, isFalse);
    await tester.tap(find.text('ZIELHILFE AUS'));
    await tester.pump();
    expect(input.assist, isTrue);

    // The switch sits right above the aim stick, in reach of the thumb.
    final toggle = tester.getRect(find.text('ZIELHILFE AN'));
    final label = tester.getRect(find.text('ZIELEN · FEUER'));
    expect(toggle.bottom, lessThan(label.top));
    expect(label.top - toggle.bottom, lessThan(40));

    final gesture = await tester.startGesture(const Offset(310, 700));
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    expect(input.aimHeld, isTrue);
    expect(input.aim, isNotNull);
    await gesture.up();
    await tester.pump();
    expect(input.aimHeld, isFalse);
  });

  testWidgets('the stick labels stay on screen', (tester) async {
    tester.view
      ..physicalSize = const Size(844, 390)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TouchControls(
            input: TouchInput(),
            special: ValueNotifier<(SpecialWeapon, int)?>(null),
          ),
        ),
      ),
    );
    for (final label in ['FAHREN', 'ZIELEN · FEUER']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(0), reason: label);
      expect(rect.right, lessThanOrEqualTo(844), reason: label);
    }
  });

  group('on a Vision Pro', () {
    setUp(() => onVisionForTesting = true);
    tearDown(() => onVisionForTesting = false);

    testWidgets('a pinch aims where the player looks and fires while held', (
      tester,
    ) async {
      Offset? looked;
      final input = await pump(tester, onLook: (at) => looked = at);
      expect(find.text('ZIELEN · FEUER'), findsNothing);
      expect(find.text('HINSEHEN · PINCH'), findsOneWidget);

      final pinch = await tester.startGesture(const Offset(300, 150));
      await tester.pump();
      expect(looked, const Offset(300, 150));
      // The game aims at the point itself, not with a stick angle.
      expect(input.aim, isNull);
      expect(input.aimHeld && input.aimFire, isTrue);

      // The other hand pinches too; letting go of one keeps firing.
      final second = await tester.startGesture(const Offset(320, 300));
      await pinch.up();
      await tester.pump();
      expect(input.aimFire, isTrue);
      await second.up();
      await tester.pump();
      expect(input.aimFire || input.aimHeld, isFalse);
    });

    testWidgets('a pinch in the lower left still drives', (tester) async {
      Offset? looked;
      final input = await pump(tester, onLook: (at) => looked = at);
      final gesture = await tester.startGesture(const Offset(90, 600));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      expect(input.drive, isNotNull);
      expect(looked, isNull);
      expect(input.aimFire, isFalse);
      await gesture.up();
    });

    testWidgets('without a game the turret points from the middle', (
      tester,
    ) async {
      final input = await pump(tester);
      final pinch = await tester.startGesture(const Offset(370, 400));
      await tester.pump();
      // Straight to the right of the middle is a quarter turn.
      expect(input.aim, closeTo(1.57, 0.1));
      await pinch.up();
    });
  });
}
