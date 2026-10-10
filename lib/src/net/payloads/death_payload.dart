class DeathPayload {
  const DeathPayload({required this.id, this.killerId, this.round});

  factory DeathPayload.fromJson(Map<String, dynamic> json) {
    return DeathPayload(
      id: json['id'] as String,
      killerId: json['killerId'] as String?,
      round: json['round'] as int?,
    );
  }

  final String id;
  final String? killerId;

  /// When the round the tank died in started. A death that arrives late,
  /// after a rematch began, must not knock the player out of the new round.
  /// Absent from older clients.
  final int? round;

  Map<String, dynamic> toJson() {
    return {'id': id, 'killerId': killerId, if (round != null) 'round': round};
  }
}
