/// One line of the kill feed.
class KillEntry {
  const KillEntry({
    required this.victim,
    required this.victimTeam,
    required this.killer,
    required this.killerTeam,
    required this.byMe,
    required this.meDied,
    required this.at,
  });

  final String victim;
  final int victimTeam;

  /// Null when the tank was lost to the closing zone or an obstacle.
  final String? killer;
  final int killerTeam;
  final bool byMe;
  final bool meDied;
  final DateTime at;
}
