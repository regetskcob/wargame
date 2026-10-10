import 'dart:math';

/// What the local player did in one round. Feeds the end screen and, added up,
/// the leaderboard.
class RoundStats {
  int shots = 0;
  int hits = 0;
  int kills = 0;
  double damage = 0;

  /// Damage the player's own tank took.
  double damageTaken = 0;

  /// Seconds from the start of the round until the player went down or the
  /// round ended. Null while still going.
  double? survived;

  /// Shells out of the own gun that have not hit yet. Guns, mines and blasts
  /// deal damage under the player's id but never count as shots, so only
  /// these may count as hits: the accuracy once read 136 % after a defense
  /// round.
  final Set<String> _inFlight = {};

  /// The own tank fired the shell [bulletId].
  void fired(String bulletId) {
    shots++;
    _inFlight.add(bulletId);
  }

  /// Something of the player's dealt [amount] of damage. [bulletId] names the
  /// shell, which counts as a hit only once and only out of the own gun.
  void hit(double amount, {String? bulletId}) {
    damage += max(0.0, amount);
    if (bulletId != null && _inFlight.remove(bulletId)) {
      hits++;
    }
  }

  void finish(double seconds) {
    survived ??= max(0, seconds);
  }

  /// Share of shells that hit a tank, 0 to 1.
  double get accuracy => shots == 0 ? 0 : min(1, hits / shots);
}
