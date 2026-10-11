import 'dart:collection';
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import 'game_config.dart';

/// One island: a centre and a shore that bulges and dents with a few waves
/// of different length, so no two look alike.
class Island {
  Island(this.centre, this.size, Random random)
    : _waves = [
        for (final (k, low, high) in const [
          (2, 0.06, 0.16),
          (3, 0.05, 0.12),
          (5, 0.02, 0.07),
          (7, 0.01, 0.04),
        ])
          (
            k,
            low + random.nextDouble() * (high - low),
            random.nextDouble() * 2 * pi,
          ),
      ];

  final Vector2 centre;

  /// The mean radius; the shore swings about a quarter around it at most.
  final double size;
  final List<(int, double, double)> _waves;

  /// Distance from [centre] to the shore in the direction [angle].
  double shoreAt(double angle) {
    var factor = 1.0;
    for (final (k, amplitude, phase) in _waves) {
      factor += amplitude * sin(k * angle + phase);
    }
    return size * factor;
  }

  /// How far [point] lies beyond the shore, negative inside.
  double beyond(Vector2 point) {
    final offset = point - centre;
    return offset.length - shoreAt(atan2(offset.y, offset.x));
  }

  /// The shore pushed out by [grow], as a closed path.
  Path outline({double grow = 0, int steps = 72}) {
    final path = Path();
    for (var i = 0; i < steps; i++) {
      final a = 2 * pi * i / steps;
      final r = shoreAt(a) + grow;
      final x = centre.x + cos(a) * r;
      final y = centre.y + sin(a) * r;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    return path..close();
  }
}

/// A wooden bridge from island [from] to island [to], a strip [halfWidth]
/// to either side of the line from [start] to [end].
class IslandBridge {
  IslandBridge(this.from, this.to, this.start, this.end);

  final int from;
  final int to;
  final Vector2 start;
  final Vector2 end;
  static const halfWidth = 28.0;

  Vector2 get along => (end - start).normalized();
  double get length => start.distanceTo(end);

  bool carries(Vector2 point) {
    final offset = point - start;
    final a = offset.dot(along);
    final side = (offset.x * along.y - offset.y * along.x).abs();
    return a >= 0 && a <= length && side <= halfWidth;
  }

  /// The end on island [island], and a little before it on the land.
  Vector2 entryFrom(int island) {
    final (near, sign) = island == from ? (start, -1.0) : (end, 1.0);
    return near + along * (sign * 36);
  }

  Vector2 exitTowards(int island) => entryFrom(island);
}

/// The islands map: islands of organic shape in a lagoon, joined by wooden
/// bridges. Along every shore runs a strip of shallow water that tanks wade
/// through slowly; beyond it the water is deep and nothing drives there.
///
/// A middle island takes the end of the closing zone, six islands around it
/// carry the start positions, the ones at 0 and 180 degrees the flag bases.
/// Bridges join each island of the ring to its neighbours and the middle to
/// the islands of both flag bases, the same on the red and the blue side.
///
/// Everything follows from the round seed, so every client agrees on it.
class IslandShape {
  IslandShape.forSeed(int seed) {
    final random = Random(seed ^ 0x15a7d);
    islands.add(Island(Vector2.zero(), 215 + random.nextDouble() * 30, random));
    for (var k = 0; k < 6; k++) {
      // The flag bases stand at 0 and 180 degrees, on islands that do not
      // move off them; the others drift a little.
      final fixed = k % 3 == 0;
      final angle =
          k * pi / 3 + (fixed ? 0 : (random.nextDouble() - 0.5) * 0.3);
      final distance =
          GameConfig.spawnRadius +
          (fixed ? 0 : (random.nextDouble() - 0.5) * 70);
      islands.add(
        Island(
          Vector2(cos(angle), sin(angle))..scale(distance),
          fixed
              ? 175 + random.nextDouble() * 20
              : 145 + random.nextDouble() * 40,
          random,
        ),
      );
    }
    for (var k = 0; k < 6; k++) {
      _bridge(1 + k, 1 + (k + 1) % 6);
    }
    _bridge(0, 1);
    _bridge(0, 4);
  }

  /// Width of the shallows along every shore.
  static const shallows = 46.0;

  /// The middle island first, then the ring from 0 degrees on.
  final islands = <Island>[];
  final bridges = <IslandBridge>[];

  void _bridge(int a, int b) {
    final from = islands[a];
    final to = islands[b];
    final dir = (to.centre - from.centre).normalized();
    final out = atan2(dir.y, dir.x);
    // From a little inside one shore to a little inside the other.
    final start = from.centre + dir * (from.shoreAt(out) - 22);
    final end = to.centre - dir * (to.shoreAt(out + pi) - 22);
    bridges.add(IslandBridge(a, b, start, end));
  }

  /// The island [point] stands on, or -1 in the water.
  int islandAt(Vector2 point, {double margin = 0}) {
    for (var i = 0; i < islands.length; i++) {
      if (islands[i].beyond(point) < -margin) {
        return i;
      }
    }
    return -1;
  }

  /// Whether [point] is dry: on an island or on a bridge.
  bool land(Vector2 point) =>
      islandAt(point) >= 0 || bridges.any((b) => b.carries(point));

  /// Whether [point] is in the shallows along a shore, where a tank wades.
  bool shallow(Vector2 point) =>
      !land(point) && islands.any((i) => i.beyond(point) < shallows);

  /// Whether [point] is deep water, where no tank goes.
  bool deep(Vector2 point) => !land(point) && !shallow(point);

  /// The island nearest to [point], counted by how far it lies off a shore.
  int nearestIsland(Vector2 point) {
    var best = 0;
    var bestBeyond = double.infinity;
    for (var i = 0; i < islands.length; i++) {
      final beyond = islands[i].beyond(point);
      if (beyond < bestBeyond) {
        best = i;
        bestBeyond = beyond;
      }
    }
    return best;
  }

  /// [point] if it is on an island at least [margin] from the shore, else
  /// the nearest such spot on the line to the centre of the nearest island.
  Vector2 onLand(Vector2 point, {double margin = 30}) {
    if (islandAt(point, margin: margin) >= 0) {
      return point;
    }
    final island = islands[nearestIsland(point)];
    final offset = point - island.centre;
    final angle = atan2(offset.y, offset.x);
    final reach = max(0.0, island.shoreAt(angle) - margin);
    return offset.length <= reach
        ? point
        : island.centre + Vector2(cos(angle), sin(angle)) * reach;
  }

  /// Where a tank at [from] should drive next on its way to [to]: [to]
  /// itself on the same island, else the bridge on the shortest crossing.
  /// On the bridge it drives for its far end, before it for its near one.
  Vector2 waypoint(Vector2 from, Vector2 to) {
    final start = _islandOf(from);
    final goal = _islandOf(to);
    if (start == goal) {
      return to;
    }
    final next = _firstStep(start, goal);
    if (next == null) {
      return to;
    }
    final bridge = bridges.firstWhere(
      (b) =>
          (b.from == start && b.to == next) ||
          (b.to == start && b.from == next),
    );
    if (bridge.carries(from)) {
      return bridge.exitTowards(next);
    }
    return bridge.entryFrom(start);
  }

  /// The island a tank counts as being on: the one under it, the one a
  /// bridge under it leads from (whichever end is nearer), else the nearest.
  int _islandOf(Vector2 point) {
    final under = islandAt(point);
    if (under >= 0) {
      return under;
    }
    for (final bridge in bridges) {
      if (bridge.carries(point)) {
        return point.distanceTo(bridge.start) < point.distanceTo(bridge.end)
            ? bridge.from
            : bridge.to;
      }
    }
    return nearestIsland(point);
  }

  /// The island after [start] on the fewest bridges to [goal].
  int? _firstStep(int start, int goal) {
    final previous = <int, int>{start: start};
    final queue = Queue<int>()..add(start);
    while (queue.isNotEmpty) {
      final at = queue.removeFirst();
      if (at == goal) {
        break;
      }
      for (final bridge in bridges) {
        final other = bridge.from == at
            ? bridge.to
            : bridge.to == at
            ? bridge.from
            : null;
        if (other != null && !previous.containsKey(other)) {
          previous[other] = at;
          queue.add(other);
        }
      }
    }
    if (!previous.containsKey(goal)) {
      return null;
    }
    var step = goal;
    while (previous[step] != start) {
      step = previous[step]!;
    }
    return step;
  }

  /// Every shore as a closed path, pushed out by [grow].
  List<Path> outlines({double grow = 0}) => [
    for (final island in islands) island.outline(grow: grow),
  ];
}
