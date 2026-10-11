/// A soldier was run over or shot by [id]. Soldiers of the round's seed go
/// by their [index], those that came later by their [key]. [raid] marks an
/// enemy soldier that reached the base and is simply gone.
class SoldierPayload {
  const SoldierPayload({
    required this.id,
    this.index = -1,
    this.key,
    this.raid = false,
  });

  factory SoldierPayload.fromJson(Map<String, dynamic> json) => SoldierPayload(
    id: json['id'] as String,
    index: json['i'] as int? ?? -1,
    key: json['k'] as String?,
    raid: json['r'] as bool? ?? false,
  );

  final String id;
  final int index;
  final String? key;
  final bool raid;

  Map<String, dynamic> toJson() => {
    'id': id,
    'i': index,
    if (key != null) 'k': key,
    if (raid) 'r': true,
  };
}

/// [count] soldiers of [owner] take the field around [x], [y] from [at] on,
/// in milliseconds since the epoch. Every client places and moves them the
/// same way from this message alone. [para] drops them by parachute,
/// [road] sends them down the road of a defense round instead.
class SquadPayload {
  const SquadPayload({
    required this.id,
    required this.owner,
    required this.squad,
    required this.x,
    required this.y,
    required this.at,
    required this.rifles,
    this.rockets = 0,
    this.para = false,
    this.road = false,
    this.back = false,
    this.lane = 0,
  });

  factory SquadPayload.fromJson(Map<String, dynamic> json) => SquadPayload(
    id: json['id'] as String,
    owner: json['owner'] as String,
    squad: json['squad'] as String,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    at: json['at'] as int,
    rifles: json['rifles'] as int? ?? 0,
    rockets: json['rockets'] as int? ?? 0,
    para: json['para'] as bool? ?? false,
    road: json['road'] as bool? ?? false,
    back: json['back'] as bool? ?? false,
    lane: json['lane'] is int ? (json['lane'] as int).clamp(0, 1) : 0,
  );

  /// Who sent it.
  final String id;

  /// Who the squad fights for: a player, a CPU tank or an enemy of the
  /// defense. Its client aims and fires their guns.
  final String owner;
  final String squad;
  final double x;
  final double y;
  final int at;
  final int rifles;
  final int rockets;
  final bool para;
  final bool road;

  /// With [road]: marches from the base up the road instead of down to it,
  /// a squad the base sends against the enemy.
  final bool back;

  /// With [road]: the side of a duel whose road it takes.
  final int lane;

  int get count => rifles + rockets;

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner': owner,
    'squad': squad,
    'x': x,
    'y': y,
    'at': at,
    'rifles': rifles,
    if (rockets > 0) 'rockets': rockets,
    if (para) 'para': true,
    if (road) 'road': true,
    if (back) 'back': true,
    if (lane > 0) 'lane': lane,
  };
}

/// The commander [id] of the squad [squad] sends it on from [at], in
/// milliseconds since the epoch: to [x], [y] after an enemy, or with
/// [patrol] back to patrolling where it stands then. Every client walks the
/// squad the same way from these orders alone.
class SquadOrderPayload {
  const SquadOrderPayload({
    required this.id,
    required this.squad,
    required this.at,
    this.x = 0,
    this.y = 0,
    this.patrol = false,
  });

  /// Null for anything that is not a well formed order.
  static SquadOrderPayload? tryParse(Map<String, dynamic> json) {
    final id = json['id'];
    final squad = json['q'];
    final at = json['at'];
    final x = json['x'] ?? 0;
    final y = json['y'] ?? 0;
    final patrol = json['p'] ?? false;
    if (id is! String ||
        squad is! String ||
        squad.length > 80 ||
        at is! int ||
        x is! num ||
        y is! num ||
        !x.isFinite ||
        !y.isFinite ||
        patrol is! bool) {
      return null;
    }
    return SquadOrderPayload(
      id: id,
      squad: squad,
      at: at,
      x: x.toDouble(),
      y: y.toDouble(),
      patrol: patrol,
    );
  }

  final String id;
  final String squad;
  final int at;
  final double x;
  final double y;
  final bool patrol;

  Map<String, dynamic> toJson() => {
    'id': id,
    'q': squad,
    'at': at,
    if (!patrol) 'x': (x * 10).roundToDouble() / 10,
    if (!patrol) 'y': (y * 10).roundToDouble() / 10,
    if (patrol) 'p': true,
  };
}
