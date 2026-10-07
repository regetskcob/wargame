/// State of a defense round. Only the player who runs the enemies sends it,
/// everybody else mirrors it.
class DefensePayload {
  const DefensePayload({
    required this.id,
    required this.hp,
    required this.wave,
    this.nextWaveAt = 0,
    this.result = DefenseResult.running,
  });

  factory DefensePayload.fromJson(Map<String, dynamic> json) {
    return DefensePayload(
      id: json['id'] as String,
      hp: (json['hp'] as num).toDouble(),
      wave: json['wave'] as int,
      nextWaveAt: json['next'] as int? ?? 0,
      result: DefenseResult.values[json['result'] as int? ?? 0],
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

  DefensePayload copyWith({
    double? hp,
    int? wave,
    int? nextWaveAt,
    DefenseResult? result,
  }) {
    return DefensePayload(
      id: id,
      hp: hp ?? this.hp,
      wave: wave ?? this.wave,
      nextWaveAt: nextWaveAt ?? this.nextWaveAt,
      result: result ?? this.result,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hp': hp,
      'wave': wave,
      'next': nextWaveAt,
      'result': result.index,
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
  });

  factory TowerPayload.fromJson(Map<String, dynamic> json) {
    return TowerPayload(
      id: json['id'] as String,
      index: json['index'] as int,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  /// The player who built it, who also fires it.
  final String id;

  /// Counts up per player.
  final int index;
  final double x;
  final double y;

  Map<String, dynamic> toJson() {
    return {'id': id, 'index': index, 'x': x, 'y': y};
  }
}
