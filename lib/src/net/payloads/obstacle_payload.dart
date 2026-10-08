/// New health of a building, barrier or tree, sent by the player whose shell
/// hit it.
class ObstaclePayload {
  const ObstaclePayload({
    required this.id,
    required this.index,
    required this.hp,
    this.tree = false,
  });

  factory ObstaclePayload.fromJson(Map<String, dynamic> json) {
    return ObstaclePayload(
      id: json['id'] as String,
      index: json['i'] as int,
      hp: (json['hp'] as num).toDouble(),
      tree: json['t'] == 1,
    );
  }

  final String id;
  final int index;
  final double hp;

  /// The index counts trees instead of buildings and barriers.
  final bool tree;

  Map<String, dynamic> toJson() => {
    'id': id,
    'i': index,
    'hp': hp,
    if (tree) 't': 1,
  };
}
