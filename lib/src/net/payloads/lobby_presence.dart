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
    this.flag = false,
    this.mode,
    this.level,
    this.map,
    this.teams = false,
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
      flag: json['flag'] as bool? ?? false,
      // Older clients send nothing; a wrong type must not drop the member.
      mode: json['mode'] is String ? json['mode'] as String : null,
      level: json['level'] is String ? json['level'] as String : null,
      map: json['map'] is int ? json['map'] as int : null,
      teams: json['teams'] == true,
    );
  }

  /// Whether this member, claiming the host role, should keep it over the
  /// player [myId] who claims it too. The owner beats a stand-in. Two
  /// owners happen when one browser opens the room in a second tab, as
  /// both remember having opened it: then, as between two stand-ins, the
  /// smaller id keeps the role, so the room never stays with two hosts.
  bool outranksHost(String myId, {required bool iOwn}) {
    if (!host || id == myId) {
      return false;
    }
    if (owner != iOwn) {
      return owner;
    }
    return id.compareTo(myId) < 0;
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
        // Without a plausible time (none, or one from before the game
        // existed, which only a client posing as the first comer sends) a
        // member counts as the last to come.
        final byTime = _joined(a).compareTo(_joined(b));
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    final kept = {for (final member in order.take(max)) member.id};
    return [
      for (final member in members)
        if (kept.contains(member.id)) member,
    ];
  }

  static int _joined(LobbyPresence member) {
    final at = member.joinedAt;
    return at == null || at < _gameBorn ? 1 << 53 : at;
  }

  /// 2025-01-01, before the first room of the game opened.
  static const _gameBorn = 1735689600000;

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

  /// The match is a capture the flag round, its flags run by [botHost].
  final bool flag;

  /// The way to play the host picked in the waiting room, a `GameMode`
  /// name, so guests read the same mode before the round starts. Only the
  /// host sends it.
  final String? mode;

  /// The host's settings, so guests read what will be played: a
  /// `BotLevel` name, the terrain's index (-1 for a random one) and
  /// whether teams play. Only the host sends them, older hosts never.
  final String? level;
  final int? map;
  final bool teams;

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
      if (flag) 'flag': true,
      if (mode != null) 'mode': mode,
      if (level != null) 'level': level,
      if (map != null) 'map': map,
      if (teams) 'teams': true,
    };
  }
}

/// [name] as the game shows it: without control and invisible characters
/// (a right to left override turns the names after it around, a line break
/// stretches the roster), without blanks around it, and at most
/// [LobbyPresence.maxName] characters, never cutting one in half.
String cleanCallSign(String name) {
  final clean = name.replaceAll(_hidden, '').trim();
  final runes = clean.runes;
  return runes.length > LobbyPresence.maxName
      ? String.fromCharCodes(runes.take(LobbyPresence.maxName)).trim()
      : clean;
}

final _hidden = RegExp(r'[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]', unicode: true);

String _cut(String name) => cleanCallSign(name);
