import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/db/score_points.dart';
import 'package:wargame/src/db/supabase_schema.g.dart';

ScoresRow _row(String name, Map<String, int> totals) =>
    ScoresRow({'id': name, 'name': name, 'wins': 0, ...totals});

void main() {
  // The live leaderboard of October 2026 that ranked by rating alone.
  final veteran = _row('darwin', {
    'rating': 992,
    'rated_rounds': 3,
    'rounds': 13,
    'wins': 11,
    'kills': 152,
    'damage': 48504,
    'shots': 2918,
    'hits': 2744,
    'survival_seconds': 4674,
  });
  final oneEvenRound = _row('Peter Maffay', {
    'rating': 1000,
    'rated_rounds': 1,
    'rounds': 2,
    'wins': 1,
    'kills': 15,
    'damage': 5079,
    'shots': 68,
    'hits': 56,
    'survival_seconds': 524,
  });
  final oneLostRound = _row('JJCS', {
    'rating': 984,
    'rated_rounds': 1,
    'rounds': 1,
    'damage': 48,
    'shots': 19,
    'hits': 6,
    'survival_seconds': 5,
  });

  test('more rounds, wins and kills outrank a better rating', () {
    expect(veteran.rating, lessThan(oneEvenRound.rating));
    expect(veteran.points, greaterThan(oneEvenRound.points));
  });

  test('every column adds', () {
    final base = _row('a', {'rounds': 1});
    for (final more in [
      {'rounds': 2},
      {'rounds': 1, 'wins': 1},
      {'rounds': 1, 'kills': 1},
      {'rounds': 1, 'damage': 100},
      {'rounds': 1, 'shots': 10, 'hits': 10},
      {'rounds': 1, 'survival_seconds': 60},
      {'rounds': 1, 'rated_rounds': 1, 'rating': 1010},
    ]) {
      expect(_row('b', more).points, greaterThan(base.points), reason: '$more');
    }
  });

  test(
    'a rating without a rated round is only the start and counts nothing',
    () {
      final unrated = _row('a', {'rounds': 1, 'rating': 1200});
      expect(unrated.points, _row('b', {'rounds': 1}).points);
    },
  );

  test('a rating below the start never makes points negative', () {
    expect(oneLostRound.points, 0);
  });
}
