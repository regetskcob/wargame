import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/flag_match.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/net/payloads/flag_payload.dart';

FlagTank _at(int team, Vector2 position) => (team: team, position: position);

void main() {
  final redBase = FlagMatch.baseOf(1);
  final blueBase = FlagMatch.baseOf(2);

  List<FlagPayload> step(
    FlagMatch match,
    Map<String, FlagTank> tanks, [
    double dt = 0.1,
  ]) => match.step(dt, tanks, authority: 'host');

  test('the bases face each other on the left and the right', () {
    expect(redBase.x, lessThan(0));
    expect(blueBase.x, greaterThan(0));
    expect(redBase.y, 0);
  });

  test('an enemy takes the flag, the owners cannot', () {
    final match = FlagMatch();
    expect(step(match, {'r': _at(1, redBase)}), isEmpty);
    final events = step(match, {'b': _at(2, redBase)});
    expect(events.single.action, FlagAction.take);
    expect(events.single.by, 'b');
    expect(match.flags[1]!.carrier, 'b');
    expect(match.carriedBy('b'), 1);
  });

  test('bringing the flag home scores while the own flag stands', () {
    final match = FlagMatch();
    step(match, {'b': _at(2, redBase)});
    step(match, {'b': _at(2, Vector2(0, 0))});
    expect(match.flags[1]!.position, Vector2(0, 0));
    final events = step(match, {'b': _at(2, blueBase)});
    expect(events.single.action, FlagAction.capture);
    expect(match.score[2], 1);
    expect(match.flags[1]!.home, isTrue);
    expect(match.carriedBy('b'), isNull);
  });

  test('no capture while the own flag is away', () {
    final match = FlagMatch();
    step(match, {'b': _at(2, redBase), 'r': _at(1, blueBase)});
    expect(match.carriedBy('b'), 1);
    expect(match.carriedBy('r'), 2);
    final events = step(match, {'b': _at(2, blueBase), 'r': _at(1, blueBase)});
    expect(events, isEmpty);
    expect(match.score[2], 0);
  });

  test('a destroyed carrier drops the flag where it was last seen', () {
    final match = FlagMatch();
    step(match, {'b': _at(2, redBase)});
    step(match, {'b': _at(2, Vector2(-100, 50))});
    final events = step(match, {});
    expect(events.single.action, FlagAction.drop);
    expect(events.single.by, 'b');
    expect(match.flags[1]!.spot, FlagSpot.dropped);
    expect(match.flags[1]!.position, Vector2(-100, 50));
  });

  test('a comrade returns a dropped flag, an enemy picks it up again', () {
    final match = FlagMatch();
    step(match, {'b': _at(2, redBase)});
    step(match, {'b': _at(2, Vector2(-100, 50))});
    step(match, {});
    final again = step(match, {'b2': _at(2, Vector2(-100, 50))});
    expect(again.single.action, FlagAction.take);
    step(match, {});
    final back = step(match, {'r': _at(1, match.flags[1]!.position)});
    expect(back.single.action, FlagAction.back);
    expect(match.flags[1]!.home, isTrue);
  });

  test('a dropped flag goes home by itself after a while', () {
    final match = FlagMatch();
    step(match, {'b': _at(2, redBase)});
    step(match, {'b': _at(2, Vector2(0, 0))});
    step(match, {});
    final events = step(match, {}, GameConfig.flagReturnSeconds);
    expect(events.single.action, FlagAction.back);
    expect(match.flags[1]!.home, isTrue);
  });

  test('a tank carries one flag at a time', () {
    final match = FlagMatch();
    step(match, {'b': _at(2, redBase)});
    // The red flag goes along; touching nothing else changes that.
    expect(step(match, {'b': _at(2, redBase)}), isEmpty);
    expect(match.carriedBy('b'), 1);
  });

  test('three captures win, after the time the side ahead wins', () {
    final match = FlagMatch();
    expect(match.winner(0), isNull);
    match.score[1] = GameConfig.flagCaptures;
    expect(match.winner(0), 1);
    match.score
      ..[1] = 1
      ..[2] = 2;
    expect(match.winner(GameConfig.flagRoundSeconds - 1), isNull);
    expect(match.winner(GameConfig.flagRoundSeconds), 2);
  });

  test('a draw after the time goes into overtime', () {
    final match = FlagMatch();
    match.score
      ..[1] = 1
      ..[2] = 1;
    expect(match.winner(GameConfig.flagRoundSeconds + 30), isNull);
    expect(match.overtime(GameConfig.flagRoundSeconds + 30), isTrue);
    match.score[1] = 2;
    expect(match.winner(GameConfig.flagRoundSeconds + 31), 1);
  });

  test('the others take over the state of the authority', () {
    final authority = FlagMatch();
    step(authority, {'b': _at(2, redBase)});
    step(authority, {'b': _at(2, Vector2(10, 20))});
    authority.score[1] = 2;
    final payload = authority.snapshot('host', FlagAction.sync, 1);
    final copy = FlagMatch()..apply(FlagPayload.tryParse(payload.toJson())!);
    expect(copy.score[1], 2);
    expect(copy.carriedBy('b'), 1);
    expect(copy.flags[1]!.position, Vector2(10, 20));
    expect(copy.flags[2]!.position, blueBase);
  });
}
