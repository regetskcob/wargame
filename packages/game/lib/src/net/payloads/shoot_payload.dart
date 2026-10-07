class ShootPayload {
  const ShootPayload({
    required this.id,
    required this.bulletId,
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    this.tower,
  });

  factory ShootPayload.fromJson(Map<String, dynamic> json) {
    return ShootPayload(
      id: json['id'] as String,
      bulletId: json['bulletId'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      dx: (json['dx'] as num).toDouble(),
      dy: (json['dy'] as num).toDouble(),
      tower: json['tower'] as int?,
    );
  }

  final String id;
  final String bulletId;
  final double x;
  final double y;
  final double dx;
  final double dy;

  /// Set when one of the player's gun emplacements fired, not the tank.
  final int? tower;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bulletId': bulletId,
      'x': x,
      'y': y,
      'dx': dx,
      'dy': dy,
      if (tower != null) 'tower': tower,
    };
  }
}
