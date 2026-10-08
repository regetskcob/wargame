class TankStatePayload {
  const TankStatePayload({
    required this.id,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.hp,
    this.turret,
    this.shielded = false,
  });

  factory TankStatePayload.fromJson(Map<String, dynamic> json) {
    return TankStatePayload(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      vx: (json['vx'] as num).toDouble(),
      vy: (json['vy'] as num).toDouble(),
      rotation: (json['rot'] as num).toDouble(),
      hp: (json['hp'] as num).toDouble(),
      turret: (json['tur'] as num?)?.toDouble(),
      shielded: json['sh'] == 1,
    );
  }

  final String id;
  final double x;
  final double y;
  final double vx;
  final double vy;
  final double rotation;
  final double hp;

  /// World angle of the turret, absent from older clients.
  final double? turret;

  /// Whether the tank has a shield up.
  final bool shielded;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'vx': vx,
      'vy': vy,
      'rot': rotation,
      'hp': hp,
      if (turret != null) 'tur': turret,
      if (shielded) 'sh': 1,
    };
  }
}

/// The states of every CPU tank a host drives, in one message: Realtime
/// counts messages, not their size.
class TankStatesPayload {
  const TankStatesPayload({required this.id, required this.states});

  factory TankStatesPayload.fromJson(Map<String, dynamic> json) {
    final list = json['states'] as List<dynamic>;
    if (list.length > maxStates) {
      throw const FormatException('too many tank states');
    }
    return TankStatesPayload(
      id: json['id'] as String,
      states: [
        for (final state in list)
          TankStatePayload.fromJson(
            (state as Map<dynamic, dynamic>).cast<String, dynamic>(),
          ),
      ],
    );
  }

  /// More CPU tanks than any round has at once.
  static const maxStates = 24;

  /// Who sent it, the host.
  final String id;
  final List<TankStatePayload> states;

  Map<String, dynamic> toJson() => {
    'id': id,
    'states': [for (final state in states) state.toJson()],
  };
}
