import '../../game_config.dart';

/// State of a defense round. Only the player who runs the enemies sends it,
/// everybody else mirrors it.
class DefensePayload {
  const DefensePayload({
    required this.id,
    required this.hp,
    required this.wave,
    this.nextWaveAt = 0,
    this.result = DefenseResult.running,
    this.hq = 1,
    this.extended = false,
  });

  factory DefensePayload.fromJson(Map<String, dynamic> json) {
    return DefensePayload(
      id: json['id'] as String,
      hp: (json['hp'] as num).toDouble(),
      wave: json['wave'] as int,
      nextWaveAt: json['next'] as int? ?? 0,
      result: DefenseResult.values[json['result'] as int? ?? 0],
      hq: json['hq'] as int? ?? 1,
      extended: json['ext'] as bool? ?? false,
    );
  }

  final String id;

  /// Hit points left on the base.
  final double hp;

  /// Wave that is running or was the last one, 0 before the first.
  final int wave;

  /// When the next wave rolls in, 0 while one is still under way.
  final int nextWaveAt;
  final DefenseResult result;

  /// How far the base has grown, from 1 (watchtower) to 3 (fortress). It
  /// grows with waves beaten off without heavy losses.
  final int hq;

  /// The defenders chose to go on after the last regular wave. The win is
  /// safe from then on, even if the base falls.
  final bool extended;

  /// The last regular wave is beaten off and the host has yet to say
  /// whether to go on.
  bool get deciding =>
      !extended &&
      result == DefenseResult.running &&
      wave >= GameConfig.defenseWaves &&
      nextWaveAt > 0;

  DefensePayload copyWith({
    double? hp,
    int? wave,
    int? nextWaveAt,
    DefenseResult? result,
    int? hq,
    bool? extended,
  }) {
    return DefensePayload(
      id: id,
      hp: hp ?? this.hp,
      wave: wave ?? this.wave,
      nextWaveAt: nextWaveAt ?? this.nextWaveAt,
      result: result ?? this.result,
      hq: hq ?? this.hq,
      extended: extended ?? this.extended,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hp': hp,
      'wave': wave,
      'next': nextWaveAt,
      'result': result.index,
      if (hq != 1) 'hq': hq,
      if (extended) 'ext': true,
    };
  }
}

enum DefenseResult { running, won, lost }

/// A player put down a gun emplacement.
class TowerPayload {
  const TowerPayload({
    required this.id,
    required this.index,
    required this.x,
    required this.y,
    this.kind = 0,
    this.level = 1,
    this.hp,
  });

  factory TowerPayload.fromJson(Map<String, dynamic> json) {
    return TowerPayload(
      id: json['id'] as String,
      index: json['index'] as int,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      kind: json['kind'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      hp: (json['hp'] as num?)?.toDouble(),
    );
  }

  /// The player who built it, who also fires it.
  final String id;

  /// Counts up per player.
  final int index;
  final double x;
  final double y;

  /// Index of the `TowerKind`: cannon, flak or mortar.
  final int kind;

  /// Raised by upgrades, from 1 up to `TowerKind.maxLevel`. The same
  /// message with a higher level upgrades a gun that is already there.
  final int level;

  /// Hit points left, sent by the player who runs the enemies after they hit
  /// it; 0 or less destroys it. Null when it is built or upgraded.
  final double? hp;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'index': index,
      'x': x,
      'y': y,
      if (kind != 0) 'kind': kind,
      if (level != 1) 'level': level,
      if (hp != null) 'hp': hp,
    };
  }
}
