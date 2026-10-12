import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/defense/aircraft.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/tank_game.dart';

import '../../helpers/fakes.dart';

// Issue 21: when a helicopter was the last enemy of a wave, the round
// dragged on. It hung back 260 away from its prey and strafed, and tank
// shells only scratched it: find it, empty the magazine, search again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tank shells hurt a helicopter more than a scratch, flak still '
      'hits it hardest', () {
    expect(GameConfig.groundGunVsHelicopter, greaterThan(0.25));
    expect(GameConfig.groundGunVsHelicopter, lessThan(1));
    expect(GameConfig.antiAirFactor, greaterThan(1));
  });

  test('the last helicopter of a wave comes in close to its prey', () async {
    var now = clock.now();
    await withClock(Clock(() => now), () async {
      final game = await loadedGame();
      game
        ..chooseMode(GameMode.defense)
        ..startRound(startedAt: now.millisecondsSinceEpoch - 4000);
      await Future<void>.delayed(Duration.zero);
      game.update(0);
      // No wave of the director meanwhile: the helicopter is the last
      // enemy on the field.
      game.defense.value = game.defense.value!.copyWith(
        wave: 3,
        nextWaveAt: now.millisecondsSinceEpoch + 3600 * 1000,
      );
      final map = game.defenseMap!;
      final me = game.myTank!;
      // Half way down the road, away from the base and its guns.
      final (spot, _) = map.alongRoad(map.roadLength * 0.5);
      me.position.setFrom(spot);
      game.spawnAircraft('td-h-last', AirKind.helicopter);

      const step = Duration(microseconds: 33333);
      var closest = double.infinity;
      for (var t = 0.0; t < 60; t += step.inMicroseconds / 1e6) {
        // Without the comrades, which would take the helicopter on.
        for (final id
            in game.botTanks.keys
                .where((id) => id.startsWith('ally-'))
                .toList()) {
          game.botTanks.remove(id)!.removeFromParent();
        }
        me
          ..hp = me.stats.maxHp
          ..position.setFrom(spot);
        game.update(step.inMicroseconds / 1e6);
        await Future<void>.delayed(Duration.zero);
        now = now.add(step);
        final heli = game.aircraft['td-h-last'];
        if (heli == null || heli.isRemoved) {
          break;
        }
        expect(game.enemiesAlive, 0);
        closest = min(closest, heli.position.distanceTo(me.position));
      }
      // It hovers at the closer distance, well inside the 260 it kept
      // before, where a phone shows it.
      expect(
        closest,
        lessThan(GameConfig.helicopterHoverLast + 50),
        reason: 'closest $closest',
      );
      expect(closest, lessThan(GameConfig.helicopterHover - 50));
    });
  });

  // Apple TV, 1.6.0: the Siri Remote aims only through the assist, which
  // went for helicopters with the Habicht alone. With no flak the last
  // helicopter of a wave could not be shot and the wave never ended.
  test(
    'the aim assist takes the helicopter when nothing else is in range',
    () async {
      final game = await loadedGame();
      game
        ..chooseMode(GameMode.defense)
        ..startRound();
      await Future<void>.delayed(Duration.zero);
      game.update(0);
      final me = game.myTank!;
      game.spawnAircraft('td-h-last', AirKind.helicopter);
      game.update(0);
      await Future<void>.delayed(Duration.zero);
      final heli = game.aircraft['td-h-last']!;
      heli.position.setFrom(me.position + Vector2(120, 0));
      expect(game.enemiesAlive, 0);
      expect(game.assistTarget(me), same(heli));
    },
  );
}
