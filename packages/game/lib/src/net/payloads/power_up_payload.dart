class PickupPayload {
  const PickupPayload({required this.id, required this.powerUpId});

  factory PickupPayload.fromJson(Map<String, dynamic> json) {
    return PickupPayload(
      id: json['id'] as String,
      powerUpId: json['powerUpId'] as int,
    );
  }

  final String id;
  final int powerUpId;

  Map<String, dynamic> toJson() => {'id': id, 'powerUpId': powerUpId};
}

class SmokePayload {
  const SmokePayload({required this.id, required this.x, required this.y});

  factory SmokePayload.fromJson(Map<String, dynamic> json) {
    return SmokePayload(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  final String id;
  final double x;
  final double y;

  Map<String, dynamic> toJson() => {'id': id, 'x': x, 'y': y};
}
