import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/net/payloads/defense_payload.dart';

void main() {
  test('a wave counts as held once its break runs, not while it rolls', () {
    const rolling = DefensePayload(id: 'h', hp: 900, wave: 12);
    expect(rolling.wavesHeld, 11);
    expect(rolling.copyWith(nextWaveAt: 1).wavesHeld, 12);
    // The base fell in wave 12: eleven were beaten off.
    expect(rolling.copyWith(hp: 0, result: DefenseResult.won).wavesHeld, 11);
    expect(const DefensePayload(id: 'h', hp: 900, wave: 0).wavesHeld, 0);
  });
}
