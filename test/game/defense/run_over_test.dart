import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/tank_game.dart';

import '../../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A tank only crushes soldiers it is not allied with (see the Soldier
  // branch of PlayerTank.onCollisionStart), so the squads of the base must
  // never count as fair game for the defenders' own tanks.
  test('own tanks and comrades never run over the infantry of the base, '
      'only the enemy squads', () async {
    final game = await loadedGame();
    game
      ..update(0)
      ..chooseMode(GameMode.defense)
      ..startRound();
    expect(game.round?.defense, isTrue);
    const baseSquad = 'ally-q3-0';
    const enemySquad = 'td-i-3-1';
    for (final tank in [game.myId, 'ally-0-0']) {
      expect(game.allied(baseSquad, tank), isTrue, reason: tank);
      expect(game.allied(enemySquad, tank), isFalse, reason: tank);
    }
    expect(game.allied(baseSquad, 'td-3-1'), isFalse);
  });
}
