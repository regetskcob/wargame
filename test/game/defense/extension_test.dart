import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/net/payloads/defense_payload.dart';

import '../../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an extension adds four waves and asks again after them', () {
    const last = GameConfig.defenseWaves;
    const held = DefensePayload(id: 'a', hp: 1, wave: last, nextWaveAt: 5);
    expect(held.lastWave, last);
    expect(held.canExtend, isTrue);

    final extended = held.copyWith(
      extended: true,
      until: last + GameConfig.defenseExtension,
      nextWaveAt: 9,
    );
    expect(extended.deciding, isFalse);
    expect(extended.copyWith(wave: last + 2).deciding, isFalse);
    final again = extended.copyWith(wave: last + GameConfig.defenseExtension);
    expect(again.deciding, isTrue);

    // The goal travels, and an older host's extension without one runs on.
    expect(DefensePayload.fromJson(again.toJson()).until, again.until);
    expect(held.copyWith(extended: true).lastWave, isNull);
    expect(
      DefensePayload.fromJson({...held.toJson(), 'until': 'twelve'}).until,
      isNull,
    );

    // No extension reaches past the last wave there is.
    final top = held.copyWith(
      extended: true,
      wave: GameConfig.defenseMaxWaves,
      until: GameConfig.defenseMaxWaves,
    );
    expect(top.deciding, isTrue);
    expect(top.canExtend, isFalse);
  });

  test('the host extends by a stretch and ends the secured round as a win '
      'from the question to leave', () async {
    final game = await loadedGame();
    game
      ..update(0)
      ..chooseMode(GameMode.defense)
      ..startRound();
    await Future<void>.delayed(const Duration(seconds: 3, milliseconds: 100));
    game.update(0);
    expect(game.phase.value, GamePhase.playing);
    expect(game.defenseWonAlready, isFalse);

    final now = DateTime.now().millisecondsSinceEpoch;
    game.publishDefense(
      game.defense.value!.copyWith(
        wave: GameConfig.defenseWaves,
        nextWaveAt: now + 20000,
      ),
    );
    expect(game.defense.value!.deciding, isTrue);
    expect(game.defenseWonAlready, isTrue);

    game.extendDefense();
    final state = game.defense.value!;
    expect(state.extended, isTrue);
    expect(state.until, GameConfig.defenseWaves + GameConfig.defenseExtension);
    expect(state.deciding, isFalse);
    // Still won when ended in the middle of a wave of the extension.
    game.publishDefense(state.copyWith(wave: state.wave + 1, nextWaveAt: 0));
    expect(game.defenseWonAlready, isTrue);

    game.withdrawDefense();
    expect(game.defense.value!.result, DefenseResult.won);
    expect(game.phase.value, GamePhase.roundOver);
  });
}
