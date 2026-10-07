import 'dart:math';

/// What the local player did in one round. Feeds the end screen and, added up,
/// the leaderboard.
class RoundStats {
  int shots = 0;
  int hits = 0;
  int kills = 0;
  double damage = 0;

  /// Seconds from the start of the round until the player went down or the
  /// round ended. Null while still going.
  double? survived;

  void finish(double seconds) {
    survived ??= max(0, seconds);
  }

  /// Share of shells that hit a tank, 0 to 1.
  double get accuracy => shots == 0 ? 0 : hits / shots;
}
