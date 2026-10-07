class RoundStartPayload {
  const RoundStartPayload({
    required this.seed,
    required this.startedAt,
    required this.participants,
    this.teams = const {},
    this.bots = const {},
    this.botHost,
    this.botLevel,
  });

  factory RoundStartPayload.fromJson(Map<String, dynamic> json) {
    return RoundStartPayload(
      seed: json['seed'] as int,
      startedAt: json['startedAt'] as int,
      participants: (json['participants'] as List<dynamic>).cast<String>(),
      botHost: json['botHost'] as String?,
      botLevel: json['botLevel'] as int?,
      bots: {
        for (final entry
            in (json['bots'] as Map<String, dynamic>? ?? const {}).entries)
          entry.key: entry.value as int,
      },
      teams: {
        for (final entry
            in (json['teams'] as Map<String, dynamic>? ?? const {}).entries)
          entry.key: entry.value as int,
      },
    );
  }

  final int seed;
  final int startedAt;
  final List<String> participants;

  /// Team per player, 1 red and 2 blue. Empty when everybody plays alone.
  final Map<String, int> teams;

  /// Computer controlled tanks (id to look) and the player who simulates them.
  final Map<String, int> bots;
  final String? botHost;

  /// Index of the [BotLevel], absent from older clients.
  final int? botLevel;

  Map<String, dynamic> toJson() {
    return {
      'seed': seed,
      'startedAt': startedAt,
      'participants': participants,
      if (teams.isNotEmpty) 'teams': teams,
      if (bots.isNotEmpty) 'bots': bots,
      if (botHost != null) 'botHost': botHost,
      if (botLevel != null) 'botLevel': botLevel,
    };
  }
}
