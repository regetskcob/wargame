import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/tank_game.dart';

import '../helpers/fakes.dart';

void main() {
  test('a chat invitation skips the start page in its mode', () {
    final game = offlineGame()..chooseInvitedMode('duel');
    expect(game.mode.value, GameMode.defense);
    expect(game.duelNext.value, isTrue);
    expect(game.choosingMode.value, isFalse);

    game.chooseInvitedMode('flag');
    expect(game.mode.value, GameMode.flag);
    expect(game.duelNext.value, isFalse);
  });

  test('an unknown mode from a link changes nothing', () {
    final game = offlineGame();
    final before = (game.mode.value, game.choosingMode.value);
    game.chooseInvitedMode('solo');
    expect((game.mode.value, game.choosingMode.value), before);
  });
}
