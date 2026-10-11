@Tags(['balance'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/bot_brain.dart';
import 'package:wargame/src/game/bot_level.dart';
import 'package:wargame/src/game/components/tank_painter.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/tank_game.dart';

import '../helpers/fakes.dart';

/// How the stand-in for the player behaves.
enum Player {
  /// Does nothing at all.
  idle,

  /// Stands still with the aim assist on, as a phone player who only waits.
  assist,

  /// Drives and shoots like a CPU tank of that level.
  easy,
  normal,
}

/// Plays solo rounds against every difficulty with a stand-in for the
/// player and prints how often it wins. Skipped in the normal run (see
/// dart_test.yaml), start it by hand:
///
///     flutter test test/game/balance_sim_test.dart --run-skipped \
///       --dart-define=ROUNDS=60
///
/// `--dart-define=VEHICLE=wolf` puts the player into that vehicle (a
/// `TankType` name) instead of a random starter, `PLAYERS=assist,normal`
/// and `LEVELS=hard` narrow the cases.
///
/// The round clock is faked, so the closing zone and the CPU tanks' hold
/// fire run as in a real round, only faster. Results and what they led to
/// are in docs/gameplay.md "Balance".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const rounds = int.fromEnvironment('ROUNDS', defaultValue: 20);
  const vehicle = String.fromEnvironment('VEHICLE');
  const players = String.fromEnvironment('PLAYERS');
  const levels = String.fromEnvironment('LEVELS');
  bool picked(String list, String name) =>
      list.isEmpty || list.split(',').contains(name);
  const step = Duration(microseconds: 33333);

  for (final level in BotLevel.values.where((l) => picked(levels, l.name))) {
    for (final player in Player.values.where((p) => picked(players, p.name))) {
      test('${level.name} vs ${player.name}', () async {
        var wins = 0;
        var survived = 0.0;
        var kills = 0;
        for (var r = 0; r < rounds; r++) {
          var now = clock.now();
          await withClock(Clock(() => now), () async {
            final game = await loadedGame();
            if (vehicle.isNotEmpty) {
              game.myColorIndex = GameConfig.styleOf(
                TankType.values.byName(vehicle).index,
                0,
              );
            }
            game
              ..chooseMode(GameMode.solo)
              ..botLevel.value = level
              ..startRound(startedAt: now.millisecondsSinceEpoch);
            await Future<void>.delayed(Duration.zero);
            game.update(0);
            final me = game.myTank!;
            switch (player) {
              case Player.idle:
                break;
              case Player.assist:
                game.touch.assist = true;
              case Player.easy || Player.normal:
                game.world.add(
                  BotBrain(
                    tank: me,
                    controls: game.touch,
                    level: player == Player.easy
                        ? BotLevel.easy
                        : BotLevel.normal,
                  ),
                );
            }
            var seconds = 0.0;
            while (seconds < 240 && game.phase.value == GamePhase.playing) {
              game.update(step.inMicroseconds / 1e6);
              // New shells and tanks mount once their load has run: without
              // this wait no shell of the player ever reached a target.
              await Future<void>.delayed(Duration.zero);
              seconds += step.inMicroseconds / 1e6;
              now = now.add(step);
            }
            survived += seconds;
            kills += game.roundStats.kills;
            if (game.round?.winnerId == game.myId) {
              wins++;
            }
          });
        }
        // ignore: avoid_print
        print(
          'RESULT ${vehicle.isEmpty ? 'starter' : vehicle} '
          '${level.name.padRight(6)} ${player.name.padRight(7)} '
          'win ${(100 * wins / rounds).round()}% '
          'survived ${(survived / rounds).toStringAsFixed(1)}s '
          'kills ${(kills / rounds).toStringAsFixed(2)}',
        );
      }, timeout: const Timeout(Duration(minutes: 20)));
    }
  }
}
