/// New health of a building or barrier, sent by the player whose shell hit it.
class ObstaclePayload {
  const ObstaclePayload({
    required this.id,
    required this.index,
    required this.hp,
  });

  factory ObstaclePayload.fromJson(Map<String, dynamic> json) {
    return ObstaclePayload(
      id: json['id'] as String,
      index: json['i'] as int,
      hp: (json['hp'] as num).toDouble(),
    );
  }

  final String id;
  final int index;
  final double hp;

  Map<String, dynamic> toJson() => {'id': id, 'i': index, 'hp': hp};
}
