import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/net/payloads/soldier_payload.dart';

void main() {
  test('a run over soldier survives the wire', () {
    const payload = SoldierPayload(id: 'a', index: 7);
    final back = SoldierPayload.fromJson(payload.toJson());
    expect(back.id, 'a');
    expect(back.index, 7);
  });

  test(
    'a squad order survives the wire, an order to patrol without a spot',
    () {
      const stalk = SquadOrderPayload(
        id: 'a',
        squad: 'a-q0',
        at: 1000,
        x: 12.34,
        y: -5,
      );
      final back = SquadOrderPayload.tryParse(stalk.toJson())!;
      expect(back.squad, 'a-q0');
      expect(back.at, 1000);
      expect(back.x, closeTo(12.3, 0.01));
      expect(back.patrol, isFalse);
      const patrol = SquadOrderPayload(
        id: 'a',
        squad: 'seed-1',
        at: 5,
        patrol: true,
      );
      expect(patrol.toJson().containsKey('x'), isFalse);
      expect(SquadOrderPayload.tryParse(patrol.toJson())!.patrol, isTrue);
    },
  );

  test('a malformed squad order is dropped, not thrown', () {
    expect(SquadOrderPayload.tryParse({}), isNull);
    expect(
      SquadOrderPayload.tryParse({'id': 'a', 'q': 'x', 'at': 'now'}),
      isNull,
    );
    expect(
      SquadOrderPayload.tryParse({
        'id': 'a',
        'q': 'x',
        'at': 1,
        'x': double.nan,
      }),
      isNull,
    );
    expect(
      SquadOrderPayload.tryParse({'id': 'a', 'q': 'x' * 200, 'at': 1}),
      isNull,
    );
    expect(
      SquadOrderPayload.tryParse({'id': 'a', 'q': 'x', 'at': 1, 'p': 1}),
      isNull,
    );
  });
}
