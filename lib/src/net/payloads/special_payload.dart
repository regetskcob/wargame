/// A grenade left the launcher of [id] and lands at [tx], [ty].
class GrenadePayload {
  const GrenadePayload({
    required this.id,
    required this.grenadeId,
    required this.x,
    required this.y,
    required this.tx,
    required this.ty,
    this.weapon = 'grenades',
    this.power = 1,
    this.tower,
  });

  factory GrenadePayload.fromJson(Map<String, dynamic> json) {
    return GrenadePayload(
      id: json['id'] as String,
      grenadeId: json['grenadeId'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      tx: (json['tx'] as num).toDouble(),
      ty: (json['ty'] as num).toDouble(),
      weapon: json['weapon'] as String? ?? 'grenades',
      power: (json['power'] as num?)?.toDouble() ?? 1,
      tower: json['tower'] as int?,
    );
  }

  final String id;
  final String grenadeId;

  /// Name of the `SpecialWeapon`: the grenade launcher, a mortar or the
  /// shell of a mortar emplacement.
  final String weapon;

  /// Damage factor, raised by upgrading an emplacement.
  final double power;

  /// Index of the emplacement that fired, null for a tank.
  final int? tower;
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
    if (weapon != 'grenades') 'weapon': weapon,
    if (power != 1) 'power': power,
    if (tower != null) 'tower': tower,
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

/// Where an enemy aircraft of a defense round flies, and how it holds up.
/// Only the player who runs the enemies sends it. [hp] of 0 means it was
/// shot down, by [killer] if anybody.
class AirPayload {
  const AirPayload({
    required this.id,
    required this.unit,
    required this.kind,
    required this.x,
    required this.y,
    required this.angle,
    required this.hp,
    this.killer,
  });

  factory AirPayload.fromJson(Map<String, dynamic> json) => AirPayload(
    id: json['id'] as String,
    unit: json['unit'] as String,
    kind: json['kind'] as int,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    angle: (json['a'] as num).toDouble(),
    hp: (json['hp'] as num).toDouble(),
    killer: json['killer'] as String?,
  );

  final String id;
  final String unit;
  final int kind;
  final double x;
  final double y;
  final double angle;
  final double hp;
  final String? killer;

  Map<String, dynamic> toJson() => {
    'id': id,
    'unit': unit,
    'kind': kind,
    'x': x,
    'y': y,
    'a': angle,
    'hp': hp,
    if (killer != null) 'killer': killer,
  };
}

/// [id] used an item from the inventory that others need to know about to
/// believe what follows, a repair or rapid fire.
class UsePayload {
  const UsePayload({required this.id, required this.item});

  factory UsePayload.fromJson(Map<String, dynamic> json) =>
      UsePayload(id: json['id'] as String, item: json['item'] as String);

  final String id;

  /// Name of the `PowerUpType`.
  final String item;

  Map<String, dynamic> toJson() => {'id': id, 'item': item};
}
