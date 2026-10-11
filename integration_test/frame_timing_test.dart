// Release test L4 (docs/release-test-plan.md): frame times on a real
// device, as measured on the BoPad in issue 12 (E). Runs only through
// `flutter drive` in a profile build, see test_driver/perf_driver.dart.
import 'package:clock/clock.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wargame/src/app/overlay_ids.dart';
import 'package:wargame/src/game/bot_level.dart';
import 'package:wargame/src/game/defense/defense_map.dart';
import 'package:wargame/src/game/defense/tower.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/net/room.dart';
import 'package:wargame/src/ui/hud_overlay.dart';
import 'package:wargame/src/ui/theme.dart';
import 'package:wargame/src/ui/widgets/tablet_scale.dart';

import '../test/helpers/fakes.dart';

/// How long each scene is measured, `--dart-define=SECONDS=…`.
const _seconds = int.fromEnvironment('SECONDS', defaultValue: 30);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUpAll(openLocalStore);

  // A solo round, the lightest scene: the device should hold its full
  // refresh rate here.
  testWidgets('solo on normal', (tester) async {
    final game = await _show(tester);
    game
      ..chooseMode(GameMode.solo)
      ..fillWithBots.value = true
      ..botLevel.value = BotLevel.normal
      ..startRound(startedAt: clock.now().millisecondsSinceEpoch - 3100);
    await _measure(binding, tester, game, 'solo');
  });

  // The heaviest scene of issue 12: a late defense wave with a dozen guns,
  // CPU tanks, aircraft and soldiers, the base kept alive.
  testWidgets('defense, forced wave 30', (tester) async {
    final game = await _show(tester);
    game
      ..chooseMode(GameMode.defense)
      ..fillWithBots.value = true
      ..startRound(
        startedAt:
            clock.now().millisecondsSinceEpoch -
            GameConfig.firstWaveSeconds * 1000,
      );
    await tester.pump(const Duration(milliseconds: 100));
    game
      ..credits.value = 1000000
      ..publishDefense(
        game.defense.value!.copyWith(
          extended: true,
          wave: 29,
          nextWaveAt: clock.now().millisecondsSinceEpoch,
        ),
      );
    final map = game.defenseMap!;
    final me = game.myTank!;
    final spots = _buildSpots(map);
    for (var i = 0; i < 14 && spots.isNotEmpty; i++) {
      me.position.setFrom(spots.removeAt(spots.length * i ~/ 15));
      game.buildTower(TowerKind.values[i % TowerKind.values.length]);
    }
    me.position.setFrom(map.base + Vector2(0, 160));
    await _measure(binding, tester, game, 'defense_wave_30');
  });

  // Not measured on a device before (issue 12, "Needs you").
  testWidgets('capture the flag, three against three', (tester) async {
    final game = await _show(tester);
    game
      ..chooseMode(GameMode.flag)
      ..fillWithBots.value = true
      ..startRound(startedAt: clock.now().millisecondsSinceEpoch - 3100);
    await _measure(binding, tester, game, 'flag');
  });
}

/// The game with the overlays a round needs, loaded and in the waiting
/// room.
Future<TankGame> _show(WidgetTester tester) async {
  final game = offlineGame(net: FakeNet()..othersPresent = true);
  Widget none(BuildContext context, TankGame game) => const SizedBox.shrink();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildGameTheme(),
      home: GameWidget<TankGame>(
        game: game,
        overlayBuilderMap: {
          OverlayIds.lobby: none,
          OverlayIds.countdown: none,
          OverlayIds.hud: (context, game) =>
              TabletScale(child: HudOverlay(game: game)),
          OverlayIds.spectator: none,
          OverlayIds.roundOver: none,
          OverlayIds.closed: none,
          OverlayIds.tutorial: none,
        },
      ),
    ),
  );
  while (!game.isLoaded) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 100));
  return game;
}

/// Plays [_seconds] of the round with the own tank circling and firing,
/// every tank and the base kept alive, and records the frame timings
/// under [key].
Future<void> _measure(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  TankGame game,
  String key,
) async {
  // Past the countdown before measuring.
  await tester.pump(const Duration(seconds: 1));
  Future<void> play() async {
    final until = DateTime.now().add(const Duration(seconds: _seconds));
    for (var tick = 0; DateTime.now().isBefore(until); tick++) {
      game.touch
        ..thrust = true
        ..left = tick % 30 < 10
        ..fire = tick.isEven;
      final me = game.myTank;
      if (me != null) {
        me.hp = me.stats.maxHp;
      }
      final state = game.defense.value;
      if (state != null) {
        game.defense.value = state.copyWith(hp: GameConfig.baseMaxHp(state.hq));
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  await binding.watchPerformance(play, reportKey: key);
  game.touch.reset();
  await tester.pumpWidget(const SizedBox());
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
