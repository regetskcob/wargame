class LobbyPresence {
  const LobbyPresence({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.phase,
    this.team = 0,
    this.host = false,
    this.owner = false,
    this.seed,
    this.startedAt,
    this.uid,
    this.defense = false,
    this.botHost,
    this.joinedAt,
    this.pad = false,
  });

  factory LobbyPresence.fromJson(Map<String, dynamic> json) {
    return LobbyPresence(
      id: json['id'] as String,
      name: _cut(json['name'] as String),
      colorIndex: json['color'] as int,
      phase: json['phase'] as String,
      team: json['team'] as int? ?? 0,
      host: json['host'] as bool? ?? false,
      owner: json['owner'] as bool? ?? false,
      seed: json['seed'] as int?,
      startedAt: json['startedAt'] as int?,
      uid: json['uid'] as String?,
      defense: json['defense'] as bool? ?? false,
      botHost: json['botHost'] as String?,
      joinedAt: json['joined'] as int?,
      pad: json['pad'] as bool? ?? false,
    );
  }

  /// The members a room keeps when more than [max] are in it: the owner
  /// first, then whoever came first. Every client sorts the same way, so
  /// they all agree on who has to go.
  static List<LobbyPresence> admitted(List<LobbyPresence> members, int max) {
    if (members.length <= max) {
      return members;
    }
    final order = [...members]
      ..sort((a, b) {
        if (a.owner != b.owner) {
          return a.owner ? -1 : 1;
        }
        // Clients from before the limit say nothing: they were there first.
        final byTime = (a.joinedAt ?? 0).compareTo(b.joinedAt ?? 0);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    final kept = {for (final member in order.take(max)) member.id};
    return [
      for (final member in members)
        if (kept.contains(member.id)) member,
    ];
  }

  /// Longest call sign the game shows. Longer ones come only from clients
  /// that do not play by the rules and are cut.
  static const maxName = 16;

  /// Null when [json] is not a presence of this game, for example one with
  /// wrong types from a client that does not play by the rules.
  static LobbyPresence? tryParse(Map<String, dynamic> json) {
    if (json['id'] is! String ||
        json['name'] is! String ||
        json['color'] is! int ||
        json['phase'] is! String) {
      return null;
    }
    try {
      return LobbyPresence.fromJson(json);
    } on Object {
      return null;
    }
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

  /// Opened the room. Stays its host; others only stand in while away.
  final bool owner;
  final int? seed;
  final int? startedAt;

  /// Account id of the player, for the rating.
  final String? uid;

  /// The match is a defense round, run by [botHost].
  final bool defense;
  final String? botHost;

  /// When the player came into the room, in milliseconds since the epoch.
  final int? joinedAt;

  /// A phone controller steers this player's tank. The room then plays
  /// without CPU tanks filling it up, to leave Realtime room for the phone.
  final bool pad;

  bool get inMatch => seed != null && startedAt != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': colorIndex,
      'phase': phase,
      'team': team,
      'host': host,
      'owner': owner,
      'seed': seed,
      'startedAt': startedAt,
      if (uid != null) 'uid': uid,
      if (defense) 'defense': true,
      if (botHost != null) 'botHost': botHost,
      if (joinedAt != null) 'joined': joinedAt,
      if (pad) 'pad': true,
    };
  }
}

String _cut(String name) => name.length > LobbyPresence.maxName
    ? name.substring(0, LobbyPresence.maxName)
    : name;
