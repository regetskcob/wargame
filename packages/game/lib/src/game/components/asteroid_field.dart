import 'dart:math';

import 'package:flame/components.dart';

import '../../game_config.dart';
import 'asteroid.dart';
import '../map_theme.dart';
import 'obstacle.dart';

/// The terrain of a round: woods that slow and shelter, plus the buildings and
/// barriers that can be shot down. Everything is derived from the round seed.
class AsteroidField extends Component {
  AsteroidField({required this.seed}) : theme = MapTheme.forSeed(seed);

  final int seed;
  final MapTheme theme;
  final obstacles = <Obstacle>[];
  final trees = <Asteroid>[];

  Asteroid? treeAt(int index) =>
      index >= 0 && index < trees.length ? trees[index] : null;

  Obstacle? obstacleAt(int index) =>
      index >= 0 && index < obstacles.length ? obstacles[index] : null;

  @override
  void onLoad() {
    final random = Random(seed);
    final taken = <(Vector2, double)>[];

    Vector2? spot(double clearance) {
      for (var attempt = 0; attempt < 60; attempt++) {
        final distance =
            150 + random.nextDouble() * (GameConfig.worldRadius - 200);
        if ((distance - GameConfig.spawnRadius).abs() < 110) {
          continue;
        }
        final direction = random.nextDouble() * 2 * pi;
        final position = Vector2(cos(direction), sin(direction))
          ..scale(distance);
        // Keep the roads of a city free.
        if (theme.roads && (position.x.abs() < 70 || position.y.abs() < 70)) {
          continue;
        }
        if (taken.every((t) => t.$1.distanceTo(position) > t.$2 + clearance)) {
          return position;
        }
      }
      return null;
    }

    // Solid objects first so the woods never swallow them.
    for (var i = 0; i < theme.buildingCount; i++) {
      final size = Vector2(
        62 + random.nextDouble() * 48,
        50 + random.nextDouble() * 34,
      );
      if (random.nextBool()) {
        size.setValues(size.y, size.x);
      }
      final position = spot(size.length / 2 + 40);
      if (position == null) {
        continue;
      }
      taken.add((position, size.length / 2));
      final building = Building(
        index: obstacles.length,
        position: position,
        size: size,
        theme: theme,
      );
      obstacles.add(building);
      add(building);
    }
    for (var i = 0; i < theme.barrierCount; i++) {
      final horizontal = random.nextBool();
      final size = horizontal ? Vector2(58, 16) : Vector2(16, 58);
      final position = spot(60);
      if (position == null) {
        continue;
      }
      taken.add((position, 32));
      final barrier = Barrier(
        index: obstacles.length,
        position: position,
        size: size,
        theme: theme,
      );
      obstacles.add(barrier);
      add(barrier);
    }

    var placed = 0;
    var attempts = 0;
    while (placed < theme.treeCount && attempts < 5000) {
      attempts++;
      final radius = 16 + random.nextDouble() * 32;
      final position = spot(radius * 0.4);
      if (position == null) {
        continue;
      }
      taken.add((position, radius));
      final vertexCount = 8 + random.nextInt(4);
      final vertices = [
        for (var i = 0; i < vertexCount; i++)
          Vector2(cos(2 * pi * i / vertexCount), sin(2 * pi * i / vertexCount))
            ..scale(radius * (0.75 + random.nextDouble() * 0.25)),
      ];
      final tree = Asteroid(
        index: trees.length,
        position: position,
        radius: radius,
        vertices: vertices,
        angle: random.nextDouble() * 2 * pi,
        theme: theme,
      );
      trees.add(tree);
      add(tree);
      placed++;
    }
  }
}
