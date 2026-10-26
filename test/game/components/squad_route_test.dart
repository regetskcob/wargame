import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/components/squad_route.dart';
import 'package:wargame/src/game/game_config.dart';

void main() {
  SquadRoute route({String key = 'a-q0', bool Function(Vector2)? walkable}) =>
      SquadRoute(
        key: key,
        ownerId: 'a',
        start: Vector2(100, 100),
        startAt: 10,
        walkable: walkable ?? (_) => true,
      );

  test('a squad patrols a round about where it started instead of standing '
      'on the spot', () {
    final squad = route();
    expect(squad.at(0), Vector2(100, 100));
    expect(squad.at(10), Vector2(100, 100));
    final places = [for (var t = 10.0; t < 120; t += 5) squad.at(t)];
    final furthest = places
        .map((p) => p.distanceTo(Vector2(100, 100)))
        .reduce((a, b) => a > b ? a : b);
    expect(furthest, greaterThan(GameConfig.patrolReach * 0.4));
    expect(furthest, lessThanOrEqualTo(GameConfig.patrolReach + 1));
    // Every client walks it the same way.
    final again = route();
    for (var t = 10.0; t < 120; t += 7) {
      expect(again.at(t), squad.at(t));
    }
    expect(squad.stalking, isFalse);
  });

  test('a patrol keeps to where it may walk', () {
    final squad = route(walkable: (point) => point.x >= 100);
    for (var t = 10.0; t < 200; t += 3) {
      expect(squad.at(t).x, greaterThanOrEqualTo(100 - 1e-6));
    }
  });

  test('an order sends the squad after an enemy at a quicker pace, and back '
      'to patrolling where it stands', () {
    final squad = route();
    final from = squad.at(20);
    final goal = from + Vector2(300, 0);
    squad.order(20, goal);
    expect(squad.stalking, isTrue);
    expect(squad.goal, goal);
    expect(squad.at(20), from);
    expect(
      squad.at(22).distanceTo(from),
      closeTo(2 * GameConfig.stalkSpeed, 0.01),
    );
    expect(squad.at(60), goal);
    squad.order(60, null);
    expect(squad.stalking, isFalse);
    expect(squad.at(60), goal);
    expect(squad.at(80).distanceTo(goal), lessThan(GameConfig.patrolReach + 1));
  });

  test('a repeated order changes nothing, a late one takes its place', () {
    final a = route();
    final b = route();
    final goal = Vector2(400, 100);
    a
      ..order(20, goal)
      ..order(30, null);
    b
      ..order(30, null)
      ..order(20, goal)
      ..order(20, goal);
    for (var t = 15.0; t < 80; t += 4) {
      expect(b.at(t), a.at(t));
    }
  });

  // A river along the y axis, 100 wide, with a bridge 40 wide across it at
  // y = 0: the defense map in small.
  bool river(Vector2 p) => p.x.abs() > 50 || p.y.abs() < 20;
  const bridge = [(-50.0, 0.0), (50.0, 0.0)];
  SquadRoute riverside(Vector2 start, {bool withBridge = true}) => SquadRoute(
    key: 'a-q1',
    ownerId: 'a',
    start: start,
    startAt: 0,
    walkable: river,
    crossings: [
      if (withBridge)
        (
          Vector2(bridge[0].$1, bridge[0].$2),
          Vector2(bridge[1].$1, bridge[1].$2),
        ),
    ],
  );

  test('an order across the river goes over the bridge, never through the '
      'water', () {
    final squad = riverside(Vector2(-150, 200))..order(5, Vector2(150, 200));
    for (var t = 5.0; t < 120; t += 0.25) {
      expect(river(squad.at(t)), isTrue, reason: 'at $t: ${squad.at(t)}');
    }
    expect(squad.at(200).distanceTo(Vector2(150, 200)), lessThan(1e-6));
  });

  test('without a bridge an order across the river stops at the shore', () {
    final squad = riverside(Vector2(-150, 200), withBridge: false)
      ..order(5, Vector2(150, 200));
    for (var t = 5.0; t < 120; t += 0.25) {
      expect(river(squad.at(t)), isTrue, reason: 'at $t: ${squad.at(t)}');
    }
    expect(squad.at(200).x, lessThan(-50));
    expect(squad.at(200).x, greaterThan(-70));
  });

  test('a patrol by the river keeps its round on the land', () {
    for (final key in ['a', 'b', 'c', 'd', 'e', 'f']) {
      final squad = SquadRoute(
        key: key,
        ownerId: null,
        start: Vector2(-80, 300),
        startAt: 0,
        walkable: river,
      );
      for (var t = 0.0; t < 300; t += 0.5) {
        expect(river(squad.at(t)), isTrue, reason: '$key at $t');
      }
    }
  });
}
