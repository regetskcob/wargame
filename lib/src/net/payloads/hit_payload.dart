class HitPayload {
  const HitPayload({
    required this.id,
    required this.shooterId,
    required this.bulletId,
    required this.hp,
  });

  factory HitPayload.fromJson(Map<String, dynamic> json) {
    return HitPayload(
      id: json['id'] as String,
      shooterId: json['shooterId'] as String,
      bulletId: json['bulletId'] as String,
      hp: (json['hp'] as num).toDouble(),
    );
  }

  final String id;
  final String shooterId;
  final String bulletId;
  final double hp;

  Map<String, dynamic> toJson() {
    return {'id': id, 'shooterId': shooterId, 'bulletId': bulletId, 'hp': hp};
  }
}
