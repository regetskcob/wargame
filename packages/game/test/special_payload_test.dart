import 'package:flutter_test/flutter_test.dart';
import 'package:game/src/game/components/power_up.dart';
import 'package:game/src/net/payloads/ship_state_payload.dart';
import 'package:game/src/net/payloads/strike_payload.dart';

void main() {
  test('mines survive the wire', () {
    const payload = MinePayload(
      id: 'a',
      mines: [(id: 'a-m0', x: 1, y: 2), (id: 'a-m1', x: -3.5, y: 4)],
    );
    final back = MinePayload.fromJson(payload.toJson());
    expect(back.id, 'a');
    expect(back.mines, payload.mines);
  });

  test('a barrage survives the wire', () {
    const payload = ArtilleryPayload(
      id: 'a',
      strikeId: 'a-a0',
      x: 10,
      y: -20,
      at: 123456,
    );
    final back = ArtilleryPayload.fromJson(payload.toJson());
    expect(
      (back.id, back.strikeId, back.x, back.y, back.at),
      ('a', 'a-a0', 10.0, -20.0, 123456),
    );
  });

  test('the shield flag travels only when it is up', () {
    const down = ShipStatePayload(
      id: 'a',
      x: 0,
      y: 0,
      vx: 0,
      vy: 0,
      rotation: 0,
      hp: 1,
    );
    expect(down.toJson().containsKey('sh'), isFalse);
    const up = ShipStatePayload(
      id: 'a',
      x: 0,
      y: 0,
      vx: 0,
      vy: 0,
      rotation: 0,
      hp: 1,
      shielded: true,
    );
    expect(ShipStatePayload.fromJson(up.toJson()).shielded, isTrue);
  });

  test('every crate type turns up over a few rounds', () {
    final seen = <PowerUpType>{
      for (var seed = 0; seed < 20; seed++)
        for (final slot in PowerUpSlot.schedule(seed)) slot.type,
    };
    expect(seen, PowerUpType.values.toSet());
  });
}
