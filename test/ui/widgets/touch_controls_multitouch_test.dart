import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/special_weapon.dart';
import 'package:wargame/src/game/touch_input.dart';
import 'package:wargame/src/ui/widgets/touch_controls.dart';

/// Five fingers at once on the twin sticks, the way a tablet held in both
/// hands gets them: both thumbs on the sticks, other fingers resting on or
/// tapping the buttons, lifted in any order, some cancelled by the system.
void main() {
  const size = Size(1194, 834); // iPad Pro 11" in landscape, in points.
  late TouchInput input;
  late ValueNotifier<(SpecialWeapon, int)?> special;

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    input = TouchInput();
    special = ValueNotifier<(SpecialWeapon, int)?>((SpecialWeapon.drone, 3));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TouchControls(input: input, special: special),
        ),
      ),
    );
  }

  var nextPointer = 10;
  Future<TestGesture> finger(WidgetTester tester, Offset at) => tester
      .startGesture(at, pointer: nextPointer++, kind: PointerDeviceKind.touch);

  Offset centreOf(WidgetTester tester, String text) =>
      tester.getCenter(find.text(text));

  const driveAt = Offset(160, 700);
  const aimAt = Offset(1030, 740);

  void expectAllReleased() {
    expect(input.drive, isNull, reason: 'drive');
    expect(input.aimHeld, isFalse, reason: 'aimHeld');
    expect(input.aimFire, isFalse, reason: 'aimFire');
    expect(input.special, isFalse, reason: 'special');
  }

  testWidgets('both sticks and three more fingers, lifted in odd orders', (
    tester,
  ) async {
    await pump(tester);
    final drive = await finger(tester, driveAt);
    await drive.moveBy(const Offset(0, -50));
    final aim = await finger(tester, aimAt);
    await aim.moveBy(const Offset(-60, -10));
    await tester.pump();
    expect(input.drive, isNotNull);
    expect(input.aimHeld && input.aimFire, isTrue);

    // A third finger on the special weapon, a fourth tapping the assist, a
    // fifth resting in the middle of the screen.
    final weapon = await finger(tester, centreOf(tester, 'DROHNE'));
    await tester.pump();
    expect(input.special, isTrue);
    final tap = await finger(tester, centreOf(tester, 'ZIELHILFE AN'));
    await tap.up();
    await tester.pump();
    expect(input.assist, isFalse);
    final rest = await finger(tester, const Offset(600, 300));
    await tester.pump();

    // Both sticks keep their thumbs while the other fingers come and go.
    await drive.moveBy(const Offset(40, 0));
    await aim.moveBy(const Offset(0, 30));
    await tester.pump();
    expect(input.drive, isNotNull);
    expect(input.aimHeld, isTrue);

    // Lifted out of order: the aim thumb first, then the rest, the drive
    // thumb cancelled by the system last.
    await aim.up();
    await tester.pump();
    expect(input.aimHeld || input.aimFire, isFalse);
    expect(input.drive, isNotNull);
    await rest.up();
    await weapon.up();
    await tester.pump();
    expect(input.special, isFalse);
    await drive.cancel();
    await tester.pump();
    expectAllReleased();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a thumb sliding off a stick onto a button keeps steering', (
    tester,
  ) async {
    await pump(tester);
    final aim = await finger(tester, aimAt);
    await tester.pump();
    // Up over the special weapon and the assist button.
    await aim.moveTo(centreOf(tester, 'DROHNE'));
    await tester.pump();
    expect(input.aimHeld, isTrue);
    expect(input.special, isFalse);
    await aim.moveTo(centreOf(tester, 'ZIELHILFE AN'));
    await aim.up();
    await tester.pump();
    // Lifting over the button is no tap on it.
    expect(input.assist, isTrue);
    expectAllReleased();

    final drive = await finger(tester, driveAt);
    await drive.moveTo(const Offset(900, 100));
    await tester.pump();
    expect(input.drive, isNotNull);
    await drive.up();
    await tester.pump();
    expectAllReleased();
  });

  testWidgets('a second thumb in a stick zone takes over when the first '
      'lifts', (tester) async {
    await pump(tester);
    final first = await finger(tester, driveAt);
    await first.moveBy(const Offset(0, -50));
    await tester.pump();
    final second = await finger(tester, driveAt + const Offset(120, -40));
    await tester.pump();
    await first.up();
    await tester.pump();
    // The second thumb is still down: the stick follows it now.
    await second.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(input.drive, isNotNull);
    expect(input.drive!.$1, greaterThan(0.5));
    await second.up();
    await tester.pump();
    expectAllReleased();
  });

  testWidgets('two fingers on the special weapon hold it until both lift', (
    tester,
  ) async {
    await pump(tester);
    final at = centreOf(tester, 'DROHNE');
    final a = await finger(tester, at);
    final b = await finger(tester, at + const Offset(8, 8));
    await tester.pump();
    expect(input.special, isTrue);
    await a.up();
    await tester.pump();
    expect(input.special, isTrue);
    await b.cancel();
    await tester.pump();
    expect(input.special, isFalse);
  });

  testWidgets('controls taken away under five fingers release everything', (
    tester,
  ) async {
    await pump(tester);
    final fingers = [
      await finger(tester, driveAt),
      await finger(tester, aimAt),
      await finger(tester, centreOf(tester, 'DROHNE')),
      await finger(tester, const Offset(600, 300)),
      await finger(tester, const Offset(300, 200)),
    ];
    await fingers[0].moveBy(const Offset(30, -30));
    await fingers[1].moveBy(const Offset(-70, 0));
    await tester.pump();
    expect(input.special && input.aimFire, isTrue);
    // The special weapon spent, then the round ends under the fingers.
    special.value = null;
    await tester.pump();
    expect(input.special, isFalse);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expectAllReleased();
    for (final f in fingers) {
      await f.up();
    }
    await tester.pump();
    expectAllReleased();
    expect(tester.takeException(), isNull);
  });
}
