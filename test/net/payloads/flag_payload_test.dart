import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/net/payloads/flag_payload.dart';

void main() {
  const payload = FlagPayload(
    id: 'host',
    action: FlagAction.take,
    team: 1,
    by: 'b',
    red: 1,
    blue: 2,
    flags: [
      FlagSnapshot(spot: FlagSpot.carried, carrier: 'b', x: -12, y: 40),
      FlagSnapshot(spot: FlagSpot.dropped, x: 300, y: -20, lying: 4.5),
    ],
  );

  test('a flag message survives the wire', () {
    final copy = FlagPayload.tryParse(payload.toJson())!;
    expect(copy.id, 'host');
    expect(copy.action, FlagAction.take);
    expect(copy.team, 1);
    expect(copy.by, 'b');
    expect(copy.red, 1);
    expect(copy.blue, 2);
    expect(copy.flags[0].spot, FlagSpot.carried);
    expect(copy.flags[0].carrier, 'b');
    expect(copy.flags[1].x, 300);
    expect(copy.flags[1].lying, 4.5);
  });

  test('broken flag messages are refused', () {
    Map<String, dynamic> broken(String key, Object? value) =>
        payload.toJson()..[key] = value;
    expect(FlagPayload.tryParse({}), isNull);
    expect(FlagPayload.tryParse(broken('a', 'steal')), isNull);
    expect(FlagPayload.tryParse(broken('t', 3)), isNull);
    expect(FlagPayload.tryParse(broken('sc', [1])), isNull);
    expect(FlagPayload.tryParse(broken('sc', [-1, 0])), isNull);
    expect(FlagPayload.tryParse(broken('sc', ['1', 0])), isNull);
    expect(FlagPayload.tryParse(broken('f', [])), isNull);
    expect(FlagPayload.tryParse(broken('by', 7)), isNull);
    expect(
      FlagPayload.tryParse(
        broken('f', [
          {'s': 1, 'x': 0, 'y': 0},
          {'s': 0, 'x': 0, 'y': 0},
        ]),
      ),
      isNull,
      reason: 'a carried flag needs a carrier',
    );
    expect(
      FlagPayload.tryParse(
        broken('f', [
          {'s': 9, 'x': 0, 'y': 0},
          {'s': 0, 'x': 0, 'y': 0},
        ]),
      ),
      isNull,
    );
    expect(
      FlagPayload.tryParse(
        broken('f', [
          {'s': 0, 'x': double.nan, 'y': 0},
          {'s': 0, 'x': 0, 'y': 0},
        ]),
      ),
      isNull,
    );
  });
}
