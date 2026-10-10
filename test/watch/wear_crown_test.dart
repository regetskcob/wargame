import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/watch/wear_crown.dart';

void main() {
  tearDown(() {
    while (WearCrown.instance.enabled) {
      WearCrown.instance.disable();
    }
    WearCrown.instance.drain();
  });

  test('only a phone or the web leaves Wear OS off', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // No native side answers in a test: a phone, as before.
    await detectWear();
    expect(onWear, isFalse);
  });

  test('while enabled the crown adds up detents for the steering', () {
    final crown = WearCrown.instance..enable();
    crown
      ..receive(1, 40)
      ..receive(-0.5, -20);
    expect(crown.drain(), 0.5);
    expect(crown.drain(), 0);
  });

  test('enable and disable are counted', () {
    final crown = WearCrown.instance
      ..enable()
      ..enable()
      ..disable();
    expect(crown.enabled, isTrue);
    crown.disable();
    expect(crown.enabled, isFalse);
    crown.disable();
    expect(crown.enabled, isFalse);
  });

  testWidgets('between rounds the crown scrolls the list in the middle', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ListView(
          controller: controller,
          children: [for (var i = 0; i < 40; i++) SizedBox(height: 50)],
        ),
      ),
    );
    WearCrown.instance.receive(1, 60);
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    final down = controller.offset;
    WearCrown.instance.receive(-1, -60);
    await tester.pumpAndSettle();
    expect(controller.offset, lessThan(down));
    // Nothing was kept for the steering.
    expect(WearCrown.instance.drain(), 0);
  });
}
