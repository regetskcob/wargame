import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/tank_game.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // In red against blue every hull of a side looks the same, only the ring
  // tells the player which one is theirs.
  test('only the tank this screen drives wears the own ring', () async {
    final game = await loadedGame();
    game
      ..update(0)
      ..chooseMode(GameMode.defense)
      ..startRound();
    expect(game.myTank?.own, isTrue);
    expect(game.botTanks.values.where((tank) => tank.own), isEmpty);
  });
}
