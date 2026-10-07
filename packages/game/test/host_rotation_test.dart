import 'package:flutter_test/flutter_test.dart';
import 'package:game/src/game/round_state.dart';
import 'package:game/src/net/payloads/round_start_payload.dart';

void main() {
  RoundState round({String? host, Map<String, int> bots = const {}}) {
    return RoundState(
      seed: 1,
      startedAt: 0,
      participants: ['a', 'b', 'c', ...bots.keys]..sort(),
      bots: bots,
      hostId: host,
    );
  }

  test('the next player in seating order hosts after a round', () {
    expect(round(host: 'a').nextHost({'a', 'b', 'c'}), 'b');
    expect(round(host: 'c').nextHost({'a', 'b', 'c'}), 'a');
  });

  test('players who left are skipped', () {
    expect(round(host: 'a').nextHost({'a', 'c'}), 'c');
    expect(round(host: 'a').nextHost({'a'}), 'a');
  });

  test('no handover without a known host', () {
    expect(round().nextHost({'a', 'b', 'c'}), isNull);
  });

  test('rounds against CPU tanks keep camouflage', () {
    expect(round(host: 'a').distinctColors, isTrue);
    expect(round(host: 'a', bots: {'cpu-1': 0}).distinctColors, isFalse);
    expect(round(host: 'a', bots: {'cpu-1': 0}).humans, ['a', 'b', 'c']);
  });

  test('the host travels with the round start', () {
    const payload = RoundStartPayload(
      seed: 1,
      startedAt: 2,
      participants: ['a', 'b'],
      host: 'a',
    );
    expect(RoundStartPayload.fromJson(payload.toJson()).host, 'a');
  });
}
