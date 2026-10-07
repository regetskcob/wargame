/// A grenade left the launcher of [id] and lands at [tx], [ty].
class GrenadePayload {
  const GrenadePayload({
    required this.id,
    required this.grenadeId,
    required this.x,
    required this.y,
    required this.tx,
    required this.ty,
  });

  factory GrenadePayload.fromJson(Map<String, dynamic> json) {
    return GrenadePayload(
      id: json['id'] as String,
      grenadeId: json['grenadeId'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      tx: (json['tx'] as num).toDouble(),
      ty: (json['ty'] as num).toDouble(),
    );
  }

  final String id;
  final String grenadeId;
  final double x;
  final double y;
  final double tx;
  final double ty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'grenadeId': grenadeId,
    'x': x,
    'y': y,
    'tx': tx,
    'ty': ty,
  };
}

/// Where a drone of [id] flies right now. Only its owner simulates it.
class DronePayload {
  const DronePayload({
    required this.id,
    required this.droneId,
    required this.x,
    required this.y,
    required this.angle,
  });

  factory DronePayload.fromJson(Map<String, dynamic> json) {
    return DronePayload(
      id: json['id'] as String,
      droneId: json['droneId'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      angle: (json['angle'] as num).toDouble(),
    );
  }

  final String id;
  final String droneId;
  final double x;
  final double y;
  final double angle;

  Map<String, dynamic> toJson() => {
    'id': id,
    'droneId': droneId,
    'x': x,
    'y': y,
    'angle': angle,
  };
}

/// A special weapon of [id] went off at [x], [y]. [weapon] is the name of a
/// `SpecialWeapon`, which sets radius and damage.
class BlastPayload {
  const BlastPayload({
    required this.id,
    required this.blastId,
    required this.weapon,
    required this.x,
    required this.y,
  });

  factory BlastPayload.fromJson(Map<String, dynamic> json) {
    return BlastPayload(
      id: json['id'] as String,
      blastId: json['blastId'] as String,
      weapon: json['weapon'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  final String id;
  final String blastId;
  final String weapon;
  final double x;
  final double y;

  Map<String, dynamic> toJson() => {
    'id': id,
    'blastId': blastId,
    'weapon': weapon,
    'x': x,
    'y': y,
  };
}
