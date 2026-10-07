/// A soldier was run over by the tank of [id].
class SoldierPayload {
  const SoldierPayload({required this.id, required this.index});

  factory SoldierPayload.fromJson(Map<String, dynamic> json) =>
      SoldierPayload(id: json['id'] as String, index: json['i'] as int);

  final String id;
  final int index;

  Map<String, dynamic> toJson() => {'id': id, 'i': index};
}
