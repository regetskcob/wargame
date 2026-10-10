import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/components/player_tank.dart';
import 'package:wargame/src/game/components/tank_painter.dart';
import 'package:wargame/src/game/tank_stats.dart';
import 'package:wargame/src/game/touch_input.dart';

PlayerTank _tank(TankType type, {double angle = 0}) => PlayerTank(
  playerId: 'p1',
  playerName: 'P1',
  tankColor: const Color(0xFF6B7F3A),
  tankType: type,
  position: Vector2(100, 100),
  angle: angle,
  controls: TouchInput(),
);

void main() {
  test('every tank has one drawn muzzle per barrel', () {
    for (final type in TankType.values) {
      expect(
        muzzlesOf(type).length,
        TankStats.of(type).barrels,
        reason: '$type',
      );
    }
  });

  test('shells leave a centred gun on the middle line', () {
    final starts = _tank(TankType.keiler).barrelStarts(40);
    expect(starts.single.x, closeTo(100, 1e-9));
    expect(starts.single.y, closeTo(60, 1e-9));
  });

  test('shells leave the launch tube set off to the right', () {
    final tank = _tank(TankType.spitzmaus);
    final start = tank.barrelStarts(40).single;
    expect(start.x, closeTo(103.5, 1e-9));
    expect(start.y, closeTo(60, 1e-9));

    // Turned to the right, the tube's offset points down.
    tank.turretAngle = pi / 2;
    final turned = tank.barrelStarts(40).single;
    expect(turned.y, greaterThan(100));
  });

  test('a turret ring behind the middle swings the gun around itself', () {
    final tank = _tank(TankType.hirsch);
    tank.turretAngle = pi / 2;
    final start = tank.barrelStarts(40).single;
    // The ring sits 8 behind the centre, so the gun fires from there.
    expect(start.y, closeTo(108, 1e-9));
    expect(start.x, closeTo(148, 1e-9));
  });
}
