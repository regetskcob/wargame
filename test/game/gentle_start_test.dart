import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/bot_level.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/game/weather.dart';
import 'package:wargame/src/net/room.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a device that never played starts on easy, afterwards on normal',
    () async {
      expect(roundPlayed(), isFalse);
      expect((await loadedGame()).botLevel.value, BotLevel.easy);
      rememberRoundPlayed();
      expect((await loadedGame()).botLevel.value, BotLevel.normal);
    },
  );

  test(
    'the first round of a session starts by day under a clear sky',
    () async {
      for (var i = 0; i < 5; i++) {
        final game = await loadedGame();
        game
          ..chooseMode(GameMode.solo)
          ..startRound();
        final seed = game.round!.seed;
        expect(Conditions.forSeed(seed).sky, Sky.clear);
        for (var t = 0.0; t <= 60; t += 5) {
          expect(Conditions.nightAt(seed, t), isFalse, reason: 'seed $seed');
        }
      }
    },
  );

  test(
    'CPU tanks leave people alone at the start unless they are hit',
    () async {
      final game = await loadedGame();
      game
        ..chooseMode(GameMode.solo)
        ..botLevel.value = BotLevel.normal
        ..startRound();
      // The countdown runs on the wall clock.
      await Future<void>.delayed(const Duration(seconds: 3, milliseconds: 100));
      game.update(0);
      expect(game.phase.value, GamePhase.playing);
      final me = game.myTank!;
      final bot = game.botTanks.values.first;
      // Only the player is left to go for.
      for (final other in [...game.botTanks.values.skip(1)]) {
        other.removeFromParent();
      }
      game.update(0);

      var fired = false;
      void run(double seconds) {
        for (var t = 0.0; t < seconds; t += 0.05) {
          // Close by and in the open, so only the hold keeps the gun quiet.
          bot.position.setFrom(me.position + Vector2(0, -160));
          game.update(0.05);
          fired |= bot.controls!.fire;
        }
      }

      run(BotLevel.normal.holdFire - 1);
      expect(fired, isFalse);
      bot.applyDamage(1, killerId: game.myId);
      run(2);
      expect(fired, isTrue);
    },
  );

  test('the aim assist holds its fire while the CPU tanks do', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final early = await loadedGame();
    early
      ..chooseMode(GameMode.solo)
      ..startRound(startedAt: now);
    expect(early.ceasefire, isTrue);

    final later = await loadedGame();
    later
      ..chooseMode(GameMode.solo)
      ..startRound(startedAt: now - 20000);
    expect(later.ceasefire, isFalse);
  });
}
