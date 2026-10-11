import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/net/payloads/shoot_payload.dart';

void main() {
  test('the rocket of a trench survives the wire, a plain shot stays one', () {
    const rocket = ShootPayload(
      id: 'a',
      bulletId: 'a-1',
      x: 1,
      y: 2,
      dx: 0,
      dy: -1,
      tower: 3,
      rocket: true,
    );
    final back = ShootPayload.fromJson(rocket.toJson());
    expect((back.tower, back.rocket), (3, true));
    const shot = ShootPayload(
      id: 'a',
      bulletId: 'a-2',
      x: 0,
      y: 0,
      dx: 1,
      dy: 0,
    );
    expect(shot.toJson().containsKey('rkt'), isFalse);
    expect(ShootPayload.fromJson(shot.toJson()).rocket, isFalse);
    expect(ShootPayload.fromJson({...shot.toJson(), 'rkt': 1}).rocket, isFalse);
  });
}
