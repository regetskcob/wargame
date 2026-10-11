// A long defense session takes minutes: well past the default 30 s.
@Timeout(Duration(minutes: 20))
@Tags(['benchmark'])
library;

import 'dart:math';
import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/defense/defense_map.dart';
import 'package:wargame/src/game/defense/tower.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/tank_game.dart';

import '../../helpers/fakes.dart';

/// What one stretch of the session left behind and cost.
typedef Stage = ({
  int wave,
  int components,
  int enemies,
  int aircraft,
  double updateP50,
  double updateP95,
  double renderP50,
  Map<String, int> kinds,
});

/// Release test L3 (docs/release-test-plan.md), after the long session of
/// issue 12 (E): leftovers piled up over a defense session (827 fallen
/// soldiers in their squads at wave 20, wrecks that smoked forever, a
/// replay of every position) and update and render crept up with them.
///
/// Plays a defense round with up to a dozen guns on a faked clock, forces the
/// waves 20, 30, 40 and 50 one after the other and then wave 30 twice
/// more, `SECONDS` simulated seconds each, with the base and the own tank
/// kept alive. What the field holds and what a frame costs must come back
/// to the level of the first wave 30, not keep growing. Skipped in the
/// normal run, start it by hand:
///
///     flutter test test/game/defense/long_session_bench_test.dart \
///       --run-skipped --dart-define=SECONDS=60
///
/// Prints a table per stage for the release issue. The times are those of
/// the test machine without a GPU; frame times on a device are L4.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const seconds = int.fromEnvironment('SECONDS', defaultValue: 45);
  const waves = [20, 30, 40, 50, 30, 30];
  const step = Duration(microseconds: 33333);

  test('a long defense session stays bounded', () async {
    final stages = <Stage>[];
    var now = clock.now();
    await withClock(Clock(() => now), () async {
      final game = await loadedGame(net: FakeNet()..othersPresent = true);
      game
        ..chooseMode(GameMode.defense)
        ..fillWithBots.value = true
        ..startRound(startedAt: now.millisecondsSinceEpoch - 4000);
      await Future<void>.delayed(Duration.zero);
      game.update(0);
      // Extended without an end: the director goes on wave after wave.
      game
        ..credits.value = 1000000
        ..publishDefense(
          game.defense.value!.copyWith(
            extended: true,
            wave: GameConfig.defenseWaves,
          ),
        );
      final map = game.defenseMap!;
      final me = game.myTank!;
      final spots = _buildSpots(map);
      // Up to a dozen guns of every kind along the road, as late in a real
      // session.
      for (var i = 0; i < 12 && spots.isNotEmpty; i++) {
        me.position.setFrom(spots.removeAt(spots.length * i ~/ 13));
        game.buildTower(TowerKind.values[i % TowerKind.values.length]);
      }
      final guns = game.towers.length;
      me.position.setFrom(map.base + Vector2(0, 160));

      for (final wave in waves) {
        // The wave before has just ended: the director starts this one.
        game.publishDefense(
          game.defense.value!.copyWith(
            wave: wave - 1,
            nextWaveAt: now.millisecondsSinceEpoch,
          ),
        );
        final updates = <double>[];
        final renders = <double>[];
        final watch = Stopwatch();
        final frames = (seconds / (step.inMicroseconds / 1e6)).round();
        for (var frame = 0; frame < frames; frame++) {
          final state = game.defense.value!;
          game.defense.value = state.copyWith(
            hp: GameConfig.baseMaxHp(state.hq),
          );
          me.hp = me.stats.maxHp;
          watch
            ..reset()
            ..start();
          game.update(step.inMicroseconds / 1e6);
          updates.add(watch.elapsedMicroseconds / 1000);
          if (frame % 15 == 0) {
            watch
              ..reset()
              ..start();
            final recorder = PictureRecorder();
            game.render(Canvas(recorder));
            recorder.endRecording().dispose();
            renders.add(watch.elapsedMicroseconds / 1000);
          }
          await Future<void>.delayed(Duration.zero);
          now = now.add(step);
        }
        final kinds = <String, int>{};
        for (final c in game.world.descendants()) {
          kinds.update('${c.runtimeType}', (n) => n + 1, ifAbsent: () => 1);
        }
        stages.add((
          wave: wave,
          components: kinds.values.fold(0, (a, b) => a + b),
          enemies: game.botTanks.keys
              .where((id) => id.startsWith('td-'))
              .length,
          aircraft: game.aircraft.length,
          updateP50: _percentile(updates, 0.5),
          updateP95: _percentile(updates, 0.95),
          renderP50: _percentile(renders, 0.5),
          kinds: kinds,
        ));
      }
      // ignore: avoid_print
      print(_table(stages, guns: guns, seconds: seconds));
    });

    final first30 = stages[1];
    for (final again in stages.skip(4)) {
      expect(
        again.components,
        lessThan(first30.components * 1.25 + 100),
        reason: 'the field keeps growing: ${_top(first30)} → ${_top(again)}',
      );
      expect(
        again.updateP50,
        lessThan(first30.updateP50 * 1.5 + 0.5),
        reason: 'update creeps up',
      );
      expect(
        again.renderP50,
        lessThan(first30.renderP50 * 1.5 + 0.5),
        reason: 'render creeps up',
      );
    }
    // Live entities are capped however late the wave.
    final late = stages[3];
    expect(late.enemies, lessThanOrEqualTo(GameConfig.maxEnemiesAlive));
    expect(late.aircraft, lessThanOrEqualTo(GameConfig.maxEnemyAirAlive * 2));
  });
}

double _percentile(List<double> values, double share) {
  if (values.isEmpty) {
    return 0;
  }
  final sorted = [...values]..sort();
  return sorted[min(sorted.length - 1, (sorted.length * share).floor())];
}

String _top(Stage stage) {
  final kinds = stage.kinds.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return kinds.take(6).map((e) => '${e.key} ${e.value}').join(', ');
}

String _table(List<Stage> stages, {required int guns, required int seconds}) {
  final out = StringBuffer()
    ..writeln('\nLong defense session, $guns guns, $seconds s per wave')
    ..writeln(
      '| Wave | Components | Enemy tanks | Aircraft | update p50 / p95 ms '
      '| render p50 ms | Most |',
    )
    ..writeln('| --- | --- | --- | --- | --- | --- | --- |');
  for (final s in stages) {
    out.writeln(
      '| ${s.wave} | ${s.components} | ${s.enemies} | ${s.aircraft} '
      '| ${s.updateP50.toStringAsFixed(2)} / '
      '${s.updateP95.toStringAsFixed(2)} '
      '| ${s.renderP50.toStringAsFixed(2)} | ${_top(s)} |',
    );
  }
  return out.toString();
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
