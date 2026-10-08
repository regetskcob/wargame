class DeathPayload {
  const DeathPayload({required this.id, this.killerId});

  factory DeathPayload.fromJson(Map<String, dynamic> json) {
    return DeathPayload(
      id: json['id'] as String,
      killerId: json['killerId'] as String?,
    );
  }

  final String id;
  final String? killerId;

  Map<String, dynamic> toJson() {
    return {'id': id, 'killerId': killerId};
  }
}
