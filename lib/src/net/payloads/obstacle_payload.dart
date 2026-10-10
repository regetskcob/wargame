/// New health of a building, barrier, tree or supply depot, sent by the
/// player whose shell hit it. For a depot [id] is the tank that fired, so a
/// depot going up can credit the tanks it takes along.
class ObstaclePayload {
  const ObstaclePayload({
    required this.id,
    required this.index,
    required this.hp,
    this.tree = false,
    this.depot = false,
  });

  factory ObstaclePayload.fromJson(Map<String, dynamic> json) {
    return ObstaclePayload(
      id: json['id'] as String,
      index: json['i'] as int,
      hp: (json['hp'] as num).toDouble(),
      tree: json['t'] == 1,
      depot: json['d'] == 1,
    );
  }

  final String id;
  final int index;
  final double hp;

  /// The index counts trees instead of buildings and barriers.
  final bool tree;

  /// The index counts fuel stations and ammunition depots.
  final bool depot;

  Map<String, dynamic> toJson() => {
    'id': id,
    'i': index,
    'hp': hp,
    if (tree) 't': 1,
    if (depot) 'd': 1,
  };
}
