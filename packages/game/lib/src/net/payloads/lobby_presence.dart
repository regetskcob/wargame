class LobbyPresence {
  const LobbyPresence({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.phase,
    this.team = 0,
    this.host = false,
    this.seed,
    this.startedAt,
    this.defense = false,
    this.botHost,
  });

  factory LobbyPresence.fromJson(Map<String, dynamic> json) {
    return LobbyPresence(
      id: json['id'] as String,
      name: json['name'] as String,
      colorIndex: json['color'] as int,
      phase: json['phase'] as String,
      team: json['team'] as int? ?? 0,
      host: json['host'] as bool? ?? false,
      seed: json['seed'] as int?,
      startedAt: json['startedAt'] as int?,
      defense: json['defense'] as bool? ?? false,
      botHost: json['botHost'] as String?,
    );
  }

  final String id;
  final String name;
  final int colorIndex;
  final String phase;

  /// In the lobby the team the player wants (0 for any), in a match the team
  /// they were given.
  final int team;

  /// Opened the room, so decides on mode, map and when the round starts.
  final bool host;
  final int? seed;
  final int? startedAt;

  /// The match is a defense round, run by [botHost].
  final bool defense;
  final String? botHost;

  bool get inMatch => seed != null && startedAt != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': colorIndex,
      'phase': phase,
      'team': team,
      'host': host,
      'seed': seed,
      'startedAt': startedAt,
      if (defense) 'defense': true,
      if (botHost != null) 'botHost': botHost,
    };
  }
}
