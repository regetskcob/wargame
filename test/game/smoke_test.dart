// Whole rounds take a few seconds each, many more on a busy machine:
// they get more than the default 30 s before they count as hung.
@Timeout(Duration(minutes: 3))
library;

import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/bot_level.dart';
import 'package:wargame/src/game/components/power_up.dart';
import 'package:wargame/src/game/defense/aircraft.dart';
import 'package:wargame/src/game/defense/defense_map.dart';
import 'package:wargame/src/game/defense/tower.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/tank_game.dart';

import '../helpers/fakes.dart';

// Smoke tests: every mode on every level plays for a while with the local
// tank driving, firing and using every item, and nothing may throw. They
// do not check the rules (the other tests do), only that the whole round
// with its bots, waves, aircraft, infantry and effects runs together.

/// A round of [mode] whose countdown is over, with CPU tanks wherever the
/// mode takes them. Defense starts with its first wave already due.
Future<TankGame> _round(GameMode mode, BotLevel level) async {
  final net = FakeNet()..othersPresent = true;
  final game = await loadedGame(net: net);
  game
    ..update(0)
    ..chooseMode(mode)
    ..fillWithBots.value = true
    ..botLevel.value = level;
  final now = DateTime.now().millisecondsSinceEpoch;
  game.startRound(
    startedAt: mode == GameMode.defense
        ? now - GameConfig.firstWaveSeconds * 1000
        : now - 1,
  );
  game.update(0);
  return game;
}

/// Plays [seconds] of the round at 30 frames a second, the local tank
/// circling and firing, and sets off every item once on the way.
Future<void> _play(TankGame game, {double seconds = 12}) async {
  const dt = 1 / 30;
  final frames = (seconds / dt).round();
  final items = PowerUpType.values.toList();
  for (var frame = 0; frame < frames; frame++) {
    game.touch
      ..thrust = true
      ..left = frame % 90 < 30
      ..fire = frame.isEven
      ..special = frame % 60 == 0;
    if (frame % 15 == 0 && items.isNotEmpty) {
      game.inventory.add(items.removeLast());
      game.useItem(0);
    }
    game.update(dt);
    // Components with an async onLoad, like tanks a CPU host sends, only
    // finish loading between frames, as in the app.
    await Future<void>.delayed(Duration.zero);
    if (frame % 30 == 0) {
      final recorder = PictureRecorder();
      game.render(Canvas(recorder));
      recorder.endRecording().dispose();
    }
  }
  game.touch.reset();
}

/// Points next to the road where a gun may stand, apart from each other.
List<Vector2> _buildSpots(DefenseMap map) {
  final spots = <Vector2>[];
  final area = DefenseMap.bounds;
  for (var x = area.left; x < area.right; x += 40) {
    for (var y = area.top; y < area.bottom; y += 40) {
      final at = Vector2(x, y);
      if (map.distanceToRoad(at) < DefenseMap.roadHalfWidth + 140 &&
          map.whyNotBuild(at, spots) == null) {
        spots.add(at);
      }
    }
  }
  return spots;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final level in BotLevel.values) {
    for (final mode in [GameMode.solo, GameMode.multi, GameMode.flag]) {
      test('${mode.name} on ${level.name} plays without an error', () async {
        final game = await _round(mode, level);
        expect(game.phase.value, GamePhase.playing);
        expect(game.round, isNotNull);
        await _play(game);
        expect(game.round, isNotNull);
      });
    }

    test('defense on ${level.name} plays waves with every gun, trench and '
        'aircraft on both sides without an error', () async {
      final game = await _round(GameMode.defense, level);
      expect(game.round?.defense, isTrue);
      // Past the last regular wave and extended: every gun and trench is
      // unlocked.
      game
        ..credits.value = 100000
        ..publishDefense(
          game.defense.value!.copyWith(
            extended: true,
            wave: GameConfig.defenseWaves,
          ),
        );
      final map = game.defenseMap!;
      final spots = _buildSpots(map);
      for (final kind in TowerKind.values) {
        game.myTank!.position.setFrom(spots.removeAt(0));
        game.buildTower(kind);
      }
      expect(game.towers, hasLength(TowerKind.values.length));
      // Standing at its own gun, building again upgrades that one.
      game.buildTower();
      game
        ..spawnAircraft('td-h-x', AirKind.helicopter)
        ..spawnAircraft('td-j-x', AirKind.jet)
        ..spawnEnemySquad('td-i-x', 3);
      game.myTank!.position.setFrom(map.road[map.road.length ~/ 2]);
      await _play(game, seconds: 40);
      game
        ..spawnSupport('air-h-x', AirKind.helicopter)
        ..spawnSupport('air-j-x', AirKind.jet);
      await _play(game, seconds: 20);
      expect(game.defense.value?.wave, greaterThanOrEqualTo(1));
    });
  }
}
