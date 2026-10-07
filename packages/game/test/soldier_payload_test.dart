import 'package:flutter_test/flutter_test.dart';
import 'package:game/src/net/payloads/soldier_payload.dart';

void main() {
  test('a run over soldier survives the wire', () {
    const payload = SoldierPayload(id: 'a', index: 7);
    final back = SoldierPayload.fromJson(payload.toJson());
    expect(back.id, 'a');
    expect(back.index, 7);
  });
}
