import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:game/src/game/components/tank_painter.dart';
import 'package:game/src/game/tank_damage.dart';

void main() {
  test('a fresh tank is intact and drives at full strength', () {
    final damage = TankDamage.of(140, 140);
    expect(damage.stage, DamageStage.intact);
    expect(damage.speedFactor, 1);
    expect(damage.accelerationFactor, 1);
    expect(damage.turretFactor, 1);
    expect(damage.bumpiness, 0);
    expect(damage.stallRate, 0);
    expect(damage.smokeInterval, isNull);
  });

  test('damage worsens the tank step by step', () {
    final stages = [
      for (var hp = 100.0; hp > 0; hp -= 5) TankDamage.of(hp, 100).stage,
    ];
    for (var i = 1; i < stages.length; i++) {
      expect(stages[i].index, greaterThanOrEqualTo(stages[i - 1].index));
    }
    expect(stages.last, DamageStage.burning);

    final light = TankDamage.of(70, 100);
    final heavy = TankDamage.of(10, 100);
    expect(heavy.speedFactor, lessThan(light.speedFactor));
    expect(heavy.bumpiness, greaterThan(light.bumpiness));
    expect(heavy.stallRate, greaterThan(0));
    expect(heavy.smokeInterval!, lessThan(light.smokeInterval ?? 99));
    // Even a wreck still crawls.
    expect(TankDamage.of(0, 100).speedFactor, greaterThan(0.6));
  });

  test('hit points beyond the range are clamped', () {
    expect(TankDamage.of(200, 100).wear, 0);
    expect(TankDamage.of(-20, 100).wear, 1);
  });

  test('every tank paints with scars and fire', () {
    for (final type in TankType.values) {
      final recorder = PictureRecorder();
      paintTank(
        Canvas(recorder),
        48,
        type,
        const Color(0xFF556B2F),
        wear: 0.9,
        scarSeed: 7,
        flame: 1.3,
      );
      recorder.endRecording().dispose();
    }
  });
}
