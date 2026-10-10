import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/ui/tutorial/practice.dart';

void main() {
  const bounds = Rect.fromLTWH(0, 200, 1000, 600);

  test('the turret follows the mouse and a held click hits the target', () {
    final practice = TutorialPractice(touch: false, bounds: bounds);
    final target = practice.targets.first;
    practice
      ..mouse = target.at
      ..mouseDown = true;
    for (var i = 0; i < 60 && practice.hits == 0; i++) {
      practice.tick(0.05);
    }
    expect(practice.hits, 1);
    expect(target.standing, isFalse);
    // It comes back after a moment, somewhere clear of the tank.
    practice.mouseDown = false;
    for (var i = 0; i < 40; i++) {
      practice.tick(0.05);
    }
    expect(target.standing, isTrue);
    expect(
      (target.at - practice.pos).distance,
      greaterThan(practice.tankSize * 2),
    );
  });

  test('the drive stick turns the tank toward the thumb and drives', () {
    final practice = TutorialPractice(touch: true, bounds: bounds);
    final start = practice.pos;
    practice.input.drive = (1, 0);
    for (var i = 0; i < 30; i++) {
      practice.tick(0.05);
    }
    expect(practice.heading, closeTo(pi / 2, 0.05));
    expect(practice.pos.dx, greaterThan(start.dx + 50));
  });

  test('W drives ahead and the tank stays on the stage', () {
    final practice = TutorialPractice(touch: false, bounds: bounds);
    for (var i = 0; i < 200; i++) {
      practice.tick(0.05, pressed: {LogicalKeyboardKey.keyW});
    }
    expect(practice.pos.dy, greaterThanOrEqualTo(bounds.top));
    expect(practice.pos.dy, lessThan(bounds.center.dy));
  });

  test(
    'the aim assist turns onto a target and fires while the thumb rests',
    () {
      final practice = TutorialPractice(touch: true, bounds: bounds)
        ..input.assist = true;
      for (var i = 0; i < 80 && practice.hits == 0; i++) {
        practice.tick(0.05);
      }
      expect(practice.hits, greaterThan(0));
    },
  );

  test('grenades use up charges and come back', () {
    final practice = TutorialPractice(
      touch: false,
      bounds: bounds,
      grenades: true,
    );
    for (var shot = 0; shot < 3; shot++) {
      practice
        ..tick(0.05, pressed: {LogicalKeyboardKey.keyF})
        ..tick(0.05);
    }
    expect(practice.charges, 0);
    expect(practice.lobs, isNotEmpty);
    for (var i = 0; i < 60; i++) {
      practice.tick(0.05);
    }
    expect(practice.charges, 3);
  });
}
