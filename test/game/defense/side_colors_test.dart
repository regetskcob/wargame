import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/tank_game.dart';

import '../../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the defenders drive in red and the attackers in blue', () async {
    final game = await loadedGame();
    game
      ..update(0)
      ..chooseMode(GameMode.defense);
    expect(game.lobbyColorOf(game.myId, 0), GameConfig.teamColors[1]);
    game
      ..startRound()
      ..spawnEnemy('td-1-0')
      ..spawnAlly('ally-0-0', 0);
    expect(game.myTank!.tankColor, GameConfig.teamColors[1]);
    expect(game.botTanks['ally-0-0']!.tankColor, GameConfig.teamColors[1]);
    expect(game.botTanks['td-1-0']!.tankColor, GameConfig.teamColors[2]);
  });
}
