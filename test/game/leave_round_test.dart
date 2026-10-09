import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/tank_game.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Escape asks, a second Escape takes it back and Enter leaves a solo '
      'round for the waiting room', () async {
    final game = await loadedGame();
    expect(game.handleEscape(LogicalKeyboardKey.escape), isFalse);
    game
      ..update(0)
      ..chooseMode(GameMode.solo)
      ..fillWithBots.value = true
      ..startRound();
    // The countdown runs on the wall clock.
    await Future<void>.delayed(const Duration(seconds: 3, milliseconds: 100));
    game.update(0);
    expect(game.phase.value, GamePhase.playing);

    expect(game.handleEscape(LogicalKeyboardKey.enter), isFalse);
    expect(game.handleEscape(LogicalKeyboardKey.escape), isTrue);
    expect(game.leaveAsked.value, isTrue);
    game.handleEscape(LogicalKeyboardKey.escape);
    expect(game.leaveAsked.value, isFalse);
    expect(game.phase.value, GamePhase.playing);

    game.handleEscape(LogicalKeyboardKey.escape);
    expect(game.handleEscape(LogicalKeyboardKey.enter), isTrue);
    expect(game.phase.value, GamePhase.lobby);
    expect(game.round, isNull);
    expect(game.leaveAsked.value, isFalse);
    expect(game.botTanks, isEmpty);
  });
}
