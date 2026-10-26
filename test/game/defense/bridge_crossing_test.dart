import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/components/squad_route.dart';
import 'package:wargame/src/game/defense/defense_map.dart';

void main() {
  // Squads cross the river of a defense map on its bridges, lining up on
  // the road beyond each end (SquadRoute._approach). On every layout, in
  // the single field and the duel, that line has to stay out of the water
  // as the round's soldier field sees it (TankGameDefense._setUpDefense).
  test('every bridge of every defense layout can be crossed dry', () {
    for (var layout = 0; layout < DefenseMap.layoutCount; layout++) {
      final seed = DefenseMap.seedForLayout(12345, layout);
      for (final map in [
        DefenseMap.forSeed(seed),
        DefenseMap.duelForSeed(seed),
      ]) {
        bool walkable(Vector2 point) =>
            DefenseMap.bounds.deflate(60).contains(point.toOffset()) &&
            !map.inWater(point, margin: 20);
        final route = SquadRoute(
          key: 'test',
          ownerId: null,
          start: map.bases.first,
          startAt: 0,
          walkable: walkable,
        );
        for (final bridge in map.bridges) {
          final a = bridge.centre - bridge.along * bridge.halfLength;
          final b = bridge.centre + bridge.along * bridge.halfLength;
          final near = a - bridge.along * 40;
          final far = b + bridge.along * 40;
          expect(
            route.clear(near, far),
            isTrue,
            reason: 'layout $layout, bridge at ${bridge.centre}',
          );
        }
      }
    }
  });
}
