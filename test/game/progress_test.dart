import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/components/tank_painter.dart';
import 'package:wargame/src/game/progress.dart';
import 'package:wargame/src/game/round_state.dart';
import 'package:wargame/src/game/round_stats.dart';

void main() {
  test('ranks need a little more experience each time', () {
    expect(Rank.of(0).level, 1);
    expect(Rank.of(Rank.xpFor(2) - 1).level, 1);
    expect(Rank.of(Rank.xpFor(2)).level, 2);
    expect(Rank.xpFor(3) - Rank.xpFor(2), greaterThan(Rank.xpFor(2)));
    final rank = Rank.of((Rank.xpFor(4) + Rank.xpFor(5)) ~/ 2);
    expect(rank.progress, closeTo(0.5, 0.01));
    expect(Rank.of(1 << 30).title, isNotEmpty);
  });

  RoundContext context({
    int kills = 0,
    int shots = 0,
    int hits = 0,
    double taken = 0,
    bool won = false,
    double hp = 50,
    bool night = false,
  }) {
    final stats = RoundStats()
      ..kills = kills
      ..shots = shots
      ..hits = hits
      ..damageTaken = taken;
    return RoundContext(
      stats: stats,
      won: won,
      hpLeft: hp,
      soldiers: 0,
      night: night,
      tankType: TankType.puma,
    );
  }

  Set<String> earned(RoundContext round, [Set<String> owned = const {}]) =>
      Achievement.newlyEarned(round, owned).map((a) => a.code).toSet();

  test('a clean win with three kills at night earns a handful of badges', () {
    expect(earned(context(kills: 3, won: true, night: true)), {
      'first_kill',
      'first_win',
      'triple',
      'untouched',
      'night_owl',
    });
  });

  test('badges are only handed out once', () {
    expect(earned(context(kills: 1), {'first_kill'}), isEmpty);
  });

  test('sharpshooter needs enough shots', () {
    expect(earned(context(shots: 4, hits: 4)), isNot(contains('sharpshooter')));
    expect(earned(context(shots: 10, hits: 7)), contains('sharpshooter'));
  });

  test('a close call needs a narrow win', () {
    expect(
      earned(context(won: true, hp: 12, taken: 128)),
      contains('close_call'),
    );
    expect(
      earned(context(won: true, hp: 40, taken: 60)),
      isNot(contains('close_call')),
    );
  });

  test('in a free for all the order of falling decides', () {
    final round = RoundState(
      seed: 1,
      startedAt: 0,
      participants: const ['a', 'b', 'c', 'cpu-1'],
      bots: const {'cpu-1': 0},
    );
    round
      ..markDead('c')
      ..markDead('a');
    final a = round.placementsOf('a');
    expect(a.beaten, ['c']);
    expect(a.beatenBy, ['b']);
    final b = round.placementsOf('b');
    expect(b.beaten, unorderedEquals(['a', 'c']));
    expect(b.beatenBy, isEmpty);
    expect(round.markDead('a'), isFalse);
  });

  test('in a team round the whole other team counts', () {
    final round = RoundState(
      seed: 1,
      startedAt: 0,
      participants: const ['a', 'b', 'c', 'd'],
      teams: const {'a': 1, 'b': 1, 'c': 2, 'd': 2},
    )..winnerTeam = 2;
    final a = round.placementsOf('a');
    expect(a.beaten, isEmpty);
    expect(a.beatenBy, unorderedEquals(['c', 'd']));
    expect(round.placementsOf('d').beaten, unorderedEquals(['a', 'b']));
    round.winnerTeam = null;
    expect(round.placementsOf('a').beatenBy, isEmpty);
  });
}
