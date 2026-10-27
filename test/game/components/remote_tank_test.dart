import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/components/remote_tank.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/components/tank_painter.dart';
import 'package:wargame/src/net/payloads/tank_state_payload.dart';

void main() {
  RemoteTank driving() {
    final tank = RemoteTank(
      playerId: 'p2',
      playerName: 'Zwei',
      tankColor: Colors.green,
      tankType: TankType.values.first,
      position: Vector2.zero(),
    );
    tank.applyState(
      const TankStatePayload(
        id: 'p2',
        x: 0,
        y: 0,
        vx: 200,
        vy: 0,
        rotation: 0,
        hp: 100,
      ),
    );
    return tank;
  }

  void run(RemoteTank tank, double seconds) {
    for (var frame = 0; frame < (seconds * 60).round(); frame++) {
      tank.update(1 / 60);
    }
  }

  test('rolls on with its last speed between states', () {
    final tank = driving();
    run(tank, 0.2);
    expect(tank.position.x, closeTo(40, 2));
  });

  test('stops once its states stay away', () {
    final tank = driving();
    run(tank, 3);
    final stopped = tank.position.x;
    expect(stopped, closeTo(200 * GameConfig.remoteExtrapolationSeconds, 5));
    run(tank, 10);
    expect(tank.position.x, closeTo(stopped, 0.01));
  });

  test('rolls again with the next state', () {
    final tank = driving();
    run(tank, 3);
    tank.applyState(
      const TankStatePayload(
        id: 'p2',
        x: 100,
        y: 0,
        vx: 0,
        vy: 200,
        rotation: 0,
        hp: 100,
      ),
    );
    run(tank, 0.2);
    expect(tank.position.y, greaterThan(30));
  });
}
