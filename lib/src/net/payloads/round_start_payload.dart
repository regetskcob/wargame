class RoundStartPayload {
  const RoundStartPayload({
    required this.seed,
    required this.startedAt,
    required this.participants,
    this.teams = const {},
    this.bots = const {},
    this.botHost,
    this.botLevel,
    this.defense = false,
    this.lanes = const [],
    this.flag = false,
  });

  factory RoundStartPayload.fromJson(Map<String, dynamic> json) {
    return RoundStartPayload(
      seed: json['seed'] as int,
      startedAt: json['startedAt'] as int,
      participants: (json['participants'] as List<dynamic>).cast<String>(),
      botHost: json['botHost'] as String?,
      botLevel: json['botLevel'] as int?,
      defense: json['defense'] as bool? ?? false,
      flag: json['flag'] as bool? ?? false,
      lanes: [
        for (final id in json['lanes'] as List<dynamic>? ?? const [])
          if (id is String) id,
      ],
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

  /// How far a round start may lie from this device's clock. Real ones
  /// start a countdown from now; device clocks drift by seconds, not
  /// minutes. A start in 1970 would open the round with the zone already
  /// closed, one in a year would hold everybody in the countdown.
  static const maxClockGap = Duration(minutes: 5);

  /// Tanks a round can hold with room to spare: a room of [maxPilots]
  /// filled up with CPU tanks or a capture the flag crew. Anybody can send a
  /// round start, and every name in it becomes a tank on every receiver.
  static const maxTanks = 32;

  /// Whether this could be a round a real game started at [now]
  /// (milliseconds since the epoch).
  bool plausibleAt(int now) =>
      (startedAt - now).abs() <= maxClockGap.inMilliseconds &&
      participants.isNotEmpty &&
      participants.length <= maxTanks &&
      bots.length <= maxTanks &&
      teams.length <= maxTanks * 2 &&
      lanes.length <= 2 &&
      participants.every((id) => id.isNotEmpty && id.length <= 64);

  /// Team per player, 1 red and 2 blue. Empty when everybody plays alone.
  final Map<String, int> teams;

  /// Computer controlled tanks (id to look) and the player who simulates them.
  final Map<String, int> bots;
  final String? botHost;

  /// Index of the [BotLevel], absent from older clients.
  final int? botLevel;

  /// Everybody together against waves of enemies on the fixed map, run by
  /// [botHost].
  final bool defense;

  /// A defense duel: who defends the base of each side, the first the left
  /// one. Empty for a common defense round.
  final List<String> lanes;

  /// Capture the flag, red against blue, with [botHost] as the authority
  /// over the flags.
  final bool flag;

  Map<String, dynamic> toJson() {
    return {
      'seed': seed,
      'startedAt': startedAt,
      'participants': participants,
      if (teams.isNotEmpty) 'teams': teams,
      if (bots.isNotEmpty) 'bots': bots,
      if (botHost != null) 'botHost': botHost,
      if (botLevel != null) 'botLevel': botLevel,
      if (defense) 'defense': true,
      if (lanes.isNotEmpty) 'lanes': lanes,
      if (flag) 'flag': true,
    };
  }
}
