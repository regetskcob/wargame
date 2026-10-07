/// A tank laid a few mines behind itself.
class MinePayload {
  const MinePayload({required this.id, required this.mines});

  factory MinePayload.fromJson(Map<String, dynamic> json) {
    return MinePayload(
      id: json['id'] as String,
      mines: [
        for (final mine in json['mines'] as List<dynamic>)
          (
            id: (mine as Map<String, dynamic>)['id'] as String,
            x: (mine['x'] as num).toDouble(),
            y: (mine['y'] as num).toDouble(),
          ),
      ],
    );
  }

  final String id;
  final List<({String id, double x, double y})> mines;

  Map<String, dynamic> toJson() => {
    'id': id,
    'mines': [
      for (final mine in mines) {'id': mine.id, 'x': mine.x, 'y': mine.y},
    ],
  };
}

/// A tank called in a barrage that lands on [x], [y] at [at], milliseconds
/// since the epoch, so every client sees the shells strike at the same time.
class ArtilleryPayload {
  const ArtilleryPayload({
    required this.id,
    required this.strikeId,
    required this.x,
    required this.y,
    required this.at,
    this.jetX,
    this.jetY,
  });

  factory ArtilleryPayload.fromJson(Map<String, dynamic> json) {
    return ArtilleryPayload(
      id: json['id'] as String,
      strikeId: json['strikeId'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      at: json['at'] as int,
      jetX: (json['jx'] as num?)?.toDouble(),
      jetY: (json['jy'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String strikeId;
  final double x;
  final double y;
  final int at;

  /// Set on the first bomb of an air strike from a gem: where the bomber
  /// comes in from. It passes over this bomb when it falls.
  final double? jetX;
  final double? jetY;

  Map<String, dynamic> toJson() => {
    'id': id,
    'strikeId': strikeId,
    'x': x,
    'y': y,
    'at': at,
    if (jetX != null) 'jx': jetX,
    if (jetY != null) 'jy': jetY,
  };
}
