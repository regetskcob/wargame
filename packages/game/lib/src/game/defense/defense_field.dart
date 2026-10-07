import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../game_config.dart';
import '../components/asteroid.dart';
import '../map_theme.dart';
import 'defense_map.dart';

/// Terrain of a defense round: the road the enemy follows, the base at its
/// end, a border around the field and some woods off the road.
class DefenseField extends Component {
  DefenseField({required this.seed, required this.map})
    : theme = MapTheme.forSeed(seed);

  final int seed;
  final DefenseMap map;
  final MapTheme theme;
  late final Headquarters headquarters;

  /// Woods along the road, numbered like those of the open field so shots
  /// that cut them down travel the same way.
  final trees = <Asteroid>[];

  Asteroid? treeAt(int index) =>
      index >= 0 && index < trees.length ? trees[index] : null;

  @override
  void onLoad() {
    add(_Road(map: map, theme: theme));
    headquarters = Headquarters(position: map.base.clone());
    add(headquarters);
    final random = Random(seed);
    var placed = 0;
    var attempts = 0;
    while (placed < theme.treeCount ~/ 2 && attempts < 3000) {
      attempts++;
      final position = Vector2(
        (random.nextDouble() * 2 - 1) * (DefenseMap.halfWidth - 60),
        (random.nextDouble() * 2 - 1) * (DefenseMap.halfHeight - 60),
      );
      final radius = 16 + random.nextDouble() * 26;
      if (map.distanceToRoad(position) <
              DefenseMap.roadHalfWidth + radius + 40 ||
          position.distanceTo(map.base) < 260) {
        continue;
      }
      final vertexCount = 8 + random.nextInt(4);
      final tree = Asteroid(
        index: trees.length,
        position: position,
        radius: radius,
        vertices: [
          for (var i = 0; i < vertexCount; i++)
            Vector2(
              cos(2 * pi * i / vertexCount),
              sin(2 * pi * i / vertexCount),
            )..scale(radius * (0.75 + random.nextDouble() * 0.25)),
        ],
        angle: random.nextDouble() * 2 * pi,
        theme: theme,
      );
      trees.add(tree);
      add(tree);
      placed++;
    }
  }
}

class _Road extends PositionComponent {
  _Road({required this.map, required this.theme}) : super(priority: -15);

  final DefenseMap map;
  final MapTheme theme;

  @override
  void render(Canvas canvas) {
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(
        Rect.fromCircle(center: Offset.zero, radius: GameConfig.groundReach),
      )
      ..addRect(DefenseMap.bounds);
    canvas.drawPath(outside, Paint()..color = const Color(0x66000000));
    canvas.drawRect(
      DefenseMap.bounds,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0x88FFFFFF),
    );

    final line = Path()..moveTo(map.road.first.x, map.road.first.y);
    for (final point in map.road.skip(1)) {
      line.lineTo(point.x, point.y);
    }
    final paved = theme.roads;
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = DefenseMap.roadHalfWidth * 2 + 10
        ..color = paved ? const Color(0xFF1E1F21) : const Color(0x88302618),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = DefenseMap.roadHalfWidth * 2
        ..color = paved ? const Color(0xFF2B2D30) : const Color(0xAA8A7354),
    );
    // Chevrons that point the way the enemy drives.
    final arrow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = paved ? const Color(0x88D9C14A) : const Color(0x55302618);
    for (var i = 0; i < map.road.length - 1; i++) {
      final a = map.road[i];
      final b = map.road[i + 1];
      final along = b - a;
      final length = along.length;
      if (length == 0) {
        continue;
      }
      final dir = along / length;
      final side = Vector2(-dir.y, dir.x);
      for (var d = 60.0; d < length - 40; d += 140) {
        final tip = a + dir * d;
        final back = tip - dir * 16;
        canvas.drawLine((back + side * 14).toOffset(), tip.toOffset(), arrow);
        canvas.drawLine((back - side * 14).toOffset(), tip.toOffset(), arrow);
      }
    }
  }
}

/// The base the players defend. Enemy shells and enemies that reach it wear
/// it down. Its hit points come from the player who runs the enemies.
class Headquarters extends PositionComponent {
  Headquarters({required super.position})
    : super(
        size: Vector2.all(DefenseMap.baseRadius * 2),
        anchor: Anchor.center,
        priority: 4,
      );

  double hp = GameConfig.baseHp;
  double _flash = 0;

  void flash() => _flash = 0.15;

  @override
  void onLoad() {
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    _flash = max(0, _flash - dt);
  }

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    const r = DefenseMap.baseRadius;
    canvas.drawCircle(c, r, Paint()..color = const Color(0x55000000));
    // Sandbag ring.
    canvas.drawCircle(
      c,
      r - 6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = const Color(0xFFB59B6B),
    );
    for (var i = 0; i < 16; i++) {
      final a = 2 * pi * i / 16;
      canvas.drawLine(
        c + Offset(cos(a), sin(a)) * (r - 12),
        c + Offset(cos(a), sin(a)) * r,
        Paint()
          ..strokeWidth = 1.5
          ..color = const Color(0xFF6E5A3A),
      );
    }
    final bunker = Rect.fromCenter(center: c, width: r * 1.1, height: r * 0.9);
    canvas.drawRect(
      bunker,
      Paint()
        ..color = _flash > 0
            ? const Color(0xFFFFFFFF)
            : const Color(0xFF5E6B4A),
    );
    canvas.drawRect(
      bunker,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF2B3320),
    );
    // Flag pole in the colour of the defenders.
    final pole = c + Offset(r * 0.25, -r * 0.1);
    canvas.drawLine(
      pole,
      pole + const Offset(0, -46),
      Paint()
        ..strokeWidth = 3
        ..color = const Color(0xFF2E221A),
    );
    canvas.drawRect(
      Rect.fromLTWH(pole.dx, pole.dy - 46, 26, 16),
      Paint()..color = GameConfig.teamColors[1],
    );

    final ratio = (hp / GameConfig.baseHp).clamp(0.0, 1.0);
    final bar = Rect.fromLTWH(c.dx - r, c.dy + r + 8, r * 2, 7);
    canvas.drawRect(bar, Paint()..color = const Color(0x88000000));
    canvas.drawRect(
      Rect.fromLTWH(bar.left, bar.top, bar.width * ratio, bar.height),
      Paint()
        ..color = ratio > 0.3
            ? const Color(0xFF9CCC65)
            : const Color(0xFFD1492E),
    );
  }
}
