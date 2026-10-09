import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/components/tank_painter.dart';
import 'package:wargame/src/game/plausibility.dart';
import 'package:wargame/src/game/tank_stats.dart';
import 'package:wargame/src/game/game_config.dart';

void main() {
  late DateTime now;
  late PlausibilityGuard guard;
  final keiler = TankStats.of(TankType.keiler);

  setUp(() {
    now = DateTime(2026);
    guard = PlausibilityGuard(statsOf: (_) => keiler, clock: () => now);
  });

  void wait(double seconds) {
    now = now.add(Duration(milliseconds: (seconds * 1000).round()));
  }

  test('honest driving passes untouched', () {
    guard.checkState('a', x: 0, y: 0, hp: 140);
    for (var i = 1; i <= 20; i++) {
      wait(0.05);
      final step = GameConfig.tankMaxSpeed * keiler.speed * 0.05 * i;
      final r = guard.checkState('a', x: step, y: 0, hp: 140);
      expect(r.x, step);
    }
    expect(guard.strikes, isEmpty);
  });

  test('a tank that moves too fast is held back', () {
    guard.checkState('a', x: 0, y: 0, hp: 140);
    wait(0.05);
    final r = guard.checkState('a', x: 600, y: 0, hp: 140);
    expect(r.x, lessThan(100));
    expect(guard.strikes['a'], 1);
  });

  test('health only rises after a repair crate', () {
    guard.checkState('a', x: 0, y: 0, hp: 60);
    wait(0.05);
    expect(guard.checkState('a', x: 0, y: 0, hp: 140).hp, 60);
    guard.allowRepair('a');
    wait(0.05);
    expect(
      guard.checkState('a', x: 0, y: 0, hp: 140).hp,
      60 + GameConfig.repairAmount,
    );
  });

  test('health never exceeds the maximum of the tank', () {
    expect(guard.checkState('a', x: 0, y: 0, hp: 9999).hp, keiler.maxHp);
  });

  test('shots faster than the gun reloads are dropped', () {
    guard.checkState('a', x: 0, y: 0, hp: 140);
    var accepted = 0;
    for (var i = 0; i < 40; i++) {
      wait(0.02);
      if (guard.allowShot('a', x: 40, y: 0)) {
        accepted++;
      }
    }
    // 0.8 seconds of firing: a small burst allowance plus the reload rate.
    expect(accepted, lessThan(6));
    expect(guard.strikes['a'], greaterThan(0));
  });

  test('a steady rate of fire is never dropped', () {
    guard.checkState('a', x: 0, y: 0, hp: 140);
    for (var i = 0; i < 20; i++) {
      wait(keiler.fireCooldown);
      expect(guard.allowShot('a', x: 40, y: 0), isTrue);
    }
  });

  test('a shell must start next to its tank', () {
    guard.checkState('a', x: 0, y: 0, hp: 140);
    expect(guard.allowShot('a', x: 700, y: 0), isFalse);
  });

  test('a full health tank cannot die from one message', () {
    guard.checkState('a', x: 0, y: 0, hp: 140);
    expect(guard.allowDeath('a'), isFalse);
    wait(0.05);
    guard.checkState('a', x: 0, y: 0, hp: 20);
    expect(guard.allowDeath('a'), isTrue);
  });

  test('a hit cannot take more than one volley', () {
    guard.checkState('a', x: 0, y: 0, hp: 140);
    expect(guard.checkHit('a', 'b', hp: 110), 110);
    expect(guard.checkHit('a', 'b', hp: 0), greaterThan(0));
    // A hit never heals.
    expect(guard.checkHit('a', 'b', hp: 140), lessThan(110));
  });
}
