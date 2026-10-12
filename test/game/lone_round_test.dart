import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/defense/defense_map.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/tank_game.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Feedback from 1.1.0: a battle started alone in a room without CPU
  // tanks left an empty field that only the zone could end.
  test(
    'a battle started alone brings CPU tanks even with filling off',
    () async {
      final game = await loadedGame(net: FakeNet(isHost: true));
      game
        ..update(0)
        ..chooseMode(GameMode.multi)
        ..fillWithBots.value = false
        ..startRound();
      final round = game.round!;
      expect(round.participants, contains(game.myId));
      expect(
        round.participants.where((id) => id.startsWith('cpu-')),
        isNotEmpty,
      );
    },
  );

  // Feedback from 1.1.0: at the top edge of the defense field the panel in
  // the top right covered the tank and the crates around it.
  test(
    'on a phone the camera shows a tank at the top edge below the panel',
    () async {
      final game = await loadedGame(net: FakeNet(isHost: true));
      game
        ..update(0)
        ..chooseMode(GameMode.defense)
        ..startRound();
      game.touchMode.value = true;
      game.onGameResize(Vector2(393, 852));
      final tank = game.myTank!;
      tank.position = Vector2(0, -DefenseMap.halfHeight);
      for (var i = 0; i < 10; i++) {
        game.update(1 / 30);
      }
      final scale = game.camera.viewfinder.zoom;
      final screenY =
          (tank.position.y - game.camera.viewfinder.position.y) * scale +
          852 / 2;
      expect(screenY, greaterThan(90));
    },
  );
}
