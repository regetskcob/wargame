@Tags(['balance'])
library;

import 'package:clock/clock.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/defense/defense_map.dart';
import 'package:wargame/src/game/defense/tower.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/tank_game.dart';

import '../../helpers/fakes.dart';

/// What stands at the measured spot of the road.
enum Build {
  none(null),
  trenchOnRoad(TowerKind.trench),
  trenchBeside(TowerKind.trench),
  cannon(TowerKind.cannon),
  mortar(TowerKind.mortar);

  const Build(this.kind);

  final TowerKind? kind;
}

/// Puts one gun or trench a third of the way down the road and sends three
/// squads on foot and two tanks of wave 3 past it, without the waves of
/// the director. Prints what it earned in bounties against what it cost,
/// how many soldiers reached the base, when the tanks got there and how
/// much of it was left. Skipped in the normal run, start it by hand:
///
///     flutter test test/game/defense/trench_balance_sim_test.dart \
///       --run-skipped --dart-define=ROUNDS=5
///
/// Results and what they led to are in docs/gameplay.md "Balance".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const rounds = int.fromEnvironment('ROUNDS', defaultValue: 3);
  const step = Duration(microseconds: 33333);
  const seconds = 90.0;

  for (final build in Build.values) {
    test(build.name, () async {
      var earned = 0.0;
      var raids = 0.0;
      var arrival = 0.0;
      var arrived = 0;
      var left = 0.0;
      var cost = 0;
      for (var r = 0; r < rounds; r++) {
        var now = clock.now();
        await withClock(Clock(() => now), () async {
          final game = await loadedGame();
          game
            ..chooseMode(GameMode.defense)
            ..startRound(startedAt: now.millisecondsSinceEpoch - 4000);
          await Future<void>.delayed(Duration.zero);
          game.update(0);
          // Wave 3 without the director's own waves.
          game.defense.value = game.defense.value!.copyWith(
            wave: 3,
            nextWaveAt: now.millisecondsSinceEpoch + 3600 * 1000,
          );
          final map = game.defenseMap!;
          // About a third of the way down, where every build may stand.
          var (centre, dir) = map.alongRoad(map.roadLength * 0.35);
          for (final share in const [0.35, 0.3, 0.4, 0.25, 0.45, 0.5]) {
            final (point, along) = map.alongRoad(map.roadLength * share);
            final beside =
                point +
                Vector2(-along.y, along.x) * (DefenseMap.roadHalfWidth + 50);
            if (map.whyNotBuild(point, const [], onRoad: true) == null &&
                map.whyNotBuild(beside, const []) == null) {
              (centre, dir) = (point, along);
              break;
            }
          }
          final side = Vector2(-dir.y, dir.x);
          final me = game.myTank!;
          final kind = build.kind;
          if (kind != null) {
            me.position.setFrom(
              build == Build.trenchOnRoad
                  ? centre
                  : centre + side * (DefenseMap.roadHalfWidth + 50),
            );
            game.credits.value = 1000;
            final before = game.credits.value;
            game.buildTower(kind);
            cost = before - game.credits.value;
            expect(game.towers, hasLength(1), reason: game.notice.value);
          }
          // Out of the way, behind the base.
          me.position.setFrom(map.base + Vector2(0, 160));
          final start = game.credits.value;
          final baseHp = game.defense.value!.hp;
          final reached = <String, double>{};
          var t = 0.0;
          while (t < seconds) {
            for (final (at, id) in const [(0.0, 's0'), (6.0, 's1')]) {
              if (t <= at && at < t + step.inMicroseconds / 1e6) {
                game.spawnEnemySquad('td-i-3-$id', 3);
              }
            }
            if (t <= 12 && 12 < t + step.inMicroseconds / 1e6) {
              game.spawnEnemySquad('td-i-3-s2', 3);
            }
            for (final (at, id) in const [(3.0, 'td-3-0'), (15.0, 'td-3-1')]) {
              if (t <= at && at < t + step.inMicroseconds / 1e6) {
                game.spawnEnemy(id);
              }
            }
            for (final MapEntry(key: id, value: tank)
                in game.botTanks.entries) {
              if (id.startsWith('td-') &&
                  !reached.containsKey(id) &&
                  tank.position.distanceTo(map.base) < 260) {
                reached[id] = t;
              }
            }
            // Without the comrades, which would take the enemies on
            // before they get to the measured spot or the base.
            for (final id
                in game.botTanks.keys
                    .where((id) => id.startsWith('ally-'))
                    .toList()) {
              game.botTanks.remove(id)!.removeFromParent();
            }
            game.update(step.inMicroseconds / 1e6);
            await Future<void>.delayed(Duration.zero);
            t += step.inMicroseconds / 1e6;
            now = now.add(step);
          }
          earned += game.credits.value - start;
          raids += (baseHp - game.defense.value!.hp) / 25;
          for (final time in reached.values) {
            arrival += time;
            arrived++;
          }
          final tower = game.towers.values.where((t) => !t.isHq).firstOrNull;
          left += tower == null ? 0 : tower.hp / tower.maxHp;
        });
      }
      // ignore: avoid_print
      print(
        'RESULT ${build.name.padRight(13)} cost ${cost.toString().padLeft(3)} '
        'earned ${(earned / rounds).toStringAsFixed(0).padLeft(4)} '
        'base hits ${(raids / rounds).toStringAsFixed(1).padLeft(4)} '
        'tanks at base ${arrived == 0 ? '-' : '${(arrival / arrived).toStringAsFixed(1)}s'} '
        '($arrived of ${2 * rounds}) '
        'left ${(100 * left / rounds).round()}%',
      );
    }, timeout: const Timeout(Duration(minutes: 20)));
  }
}
