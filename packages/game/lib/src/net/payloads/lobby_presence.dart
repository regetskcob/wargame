class LobbyPresence {
  const LobbyPresence({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.phase,
    this.team = 0,
    this.seed,
    this.startedAt,
  });

  factory LobbyPresence.fromJson(Map<String, dynamic> json) {
    return LobbyPresence(
      id: json['id'] as String,
      name: json['name'] as String,
      colorIndex: json['color'] as int,
      phase: json['phase'] as String,
      team: json['team'] as int? ?? 0,
      seed: json['seed'] as int?,
      startedAt: json['startedAt'] as int?,
    );
  }

  final String id;
  final String name;
  final int colorIndex;
  final String phase;

  /// In the lobby the team the player wants (0 for any), in a match the team
  /// they were given.
  final int team;
  final int? seed;
  final int? startedAt;

  bool get inMatch => seed != null && startedAt != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': colorIndex,
      'phase': phase,
      'team': team,
      'seed': seed,
      'startedAt': startedAt,
    };
  }
}
