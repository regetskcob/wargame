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
