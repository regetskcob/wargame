import 'supabase_schema.g.dart';

/// One number for the leaderboard that weighs every column a pilot has.
///
/// The Elo rating alone ranked badly: it only moves in rounds with a rated
/// opponent and starts at 1000, so a pilot with one even round stood above
/// one with a dozen rounds, eleven wins and 150 kills whose few rated
/// rounds had cost a handful of points. Points grow with everything a pilot
/// does, so more rounds, wins and kills always count, and the rating only
/// adds or takes its distance from the start.
extension ScorePoints on ScoresRow {
  /// Every round played, win or lose.
  static const perRound = 10;
  static const perWin = 50;
  static const perKill = 20;

  /// Damage dealt counts one point per this much.
  static const damagePerPoint = 20;

  /// A perfect aim earns this much per round, so accuracy only weighs as
  /// much as the rounds it was kept up for.
  static const perRoundAccuracy = 20;

  /// Time alive counts one point per this many seconds.
  static const survivalPerPoint = 30;

  /// Each rating point above or below the start of 1000.
  static const perRatingPoint = 2;

  int get points {
    final accuracy = shots > 0 ? (hits / shots).clamp(0.0, 1.0) : 0.0;
    final elo = ratedRounds > 0 ? rating - 1000 : 0;
    final total =
        perRound * rounds +
        perWin * wins +
        perKill * kills +
        damage ~/ damagePerPoint +
        (perRoundAccuracy * rounds * accuracy).round() +
        survivalSeconds ~/ survivalPerPoint +
        perRatingPoint * elo;
    return total < 0 ? 0 : total;
  }
}
