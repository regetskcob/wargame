import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/bot_level.dart';
import 'package:wargame/src/game/components/obstacle.dart';
import 'package:wargame/src/game/game_config.dart';
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
        // Already begun, so the wall clock has no say in when play starts.
        ..startRound(startedAt: DateTime.now().millisecondsSinceEpoch);
      // Let the freshly added tanks finish loading.
      await Future<void>.delayed(Duration.zero);
      game.update(0);
      expect(game.phase.value, GamePhase.playing);
      final me = game.myTank!;
      final bot = game.botTanks.values.first;
      // Only the player is left to go for.
      for (final other in [...game.botTanks.values.skip(1)]) {
        other.removeFromParent();
      }
      game.update(0);

      // The world and the spawn slot are random: put both tanks on a spot
      // with nothing solid between them, or a wall keeps the gun quiet
      // after the hit as well (one CI run in about a hundred).
      final spot = _clearLane(game, from: me.position.clone());
      var fired = false;
      void run(double seconds) {
        for (var t = 0.0; t < seconds; t += 0.05) {
          // Close by and in the open, so only the hold keeps the gun quiet.
          me.position.setFrom(spot);
          bot.position.setFrom(spot + _lane);
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

/// Where the CPU tank stands, seen from the player.
final _lane = Vector2(0, -160);

/// The point nearest to [from] from which [_lane] crosses no obstacle,
/// with room for the hulls on both sides.
Vector2 _clearLane(TankGame game, {required Vector2 from}) {
  final obstacles = game.world.descendants().whereType<Obstacle>().toList();
  bool clear(Vector2 at) {
    final lane = Rect.fromPoints(
      at.toOffset(),
      (at + _lane).toOffset(),
    ).inflate(40);
    return obstacles.every((obstacle) => !obstacle.toRect().overlaps(lane));
  }

  for (var ring = 0; ring < 20; ring++) {
    for (var step = 0; step < max(1, ring * 8); step++) {
      final angle = step * 2 * pi / max(1, ring * 8);
      final at = from + Vector2(cos(angle), sin(angle)) * (ring * 30.0);
      if (at.length < GameConfig.worldRadius - 200 && clear(at)) {
        return at;
      }
    }
  }
  fail('no open lane near $from');
}
