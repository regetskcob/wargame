import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../game_config.dart';
import '../components/asteroid.dart';
import '../components/obstacle.dart';
import '../map_theme.dart';
import 'defense_map.dart';

/// Terrain of a defense round: the road the enemy follows, the river with
/// its bridges, the base at the end of the road, woods in copses and a few
/// farm houses, and a border around the field.
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

  /// Farm houses that give cover, numbered like the open field's buildings.
  final obstacles = <Obstacle>[];

  Asteroid? treeAt(int index) =>
      index >= 0 && index < trees.length ? trees[index] : null;

  Obstacle? obstacleAt(int index) =>
      index >= 0 && index < obstacles.length ? obstacles[index] : null;

  bool _clear(Vector2 position, double radius) =>
      DefenseMap.bounds.deflate(50).contains(position.toOffset()) &&
      map.distanceToRoad(position) > DefenseMap.roadHalfWidth + radius + 40 &&
      map.distanceToRiver(position) > DefenseMap.riverHalfWidth + radius + 16 &&
      position.distanceTo(map.base) > 260 &&
      !map.bridges.any(
        (b) => b.centre.distanceTo(position) < b.halfLength + radius + 30,
      );

  @override
  void onLoad() {
    add(_River(map: map, theme: theme));
    add(_Road(map: map, theme: theme));
    headquarters = Headquarters(position: map.base.clone());
    add(headquarters);
    final random = Random(seed);
    _plantWoods(random);
    _buildHouses(random);
  }

  /// Most trees grow in copses around a few centres, some stand alone.
  void _plantWoods(Random random) {
    final copses = [
      for (var i = 0; i < 7; i++)
        Vector2(
          (random.nextDouble() * 2 - 1) * (DefenseMap.halfWidth - 120),
          (random.nextDouble() * 2 - 1) * (DefenseMap.halfHeight - 120),
        ),
    ];
    var attempts = 0;
    while (trees.length < theme.treeCount && attempts < 4000) {
      attempts++;
      final Vector2 position;
      if (random.nextDouble() < 0.7) {
        final centre = copses[random.nextInt(copses.length)];
        final a = random.nextDouble() * 2 * pi;
        position =
            centre + Vector2(cos(a), sin(a)) * (random.nextDouble() * 140);
      } else {
        position = Vector2(
          (random.nextDouble() * 2 - 1) * (DefenseMap.halfWidth - 60),
          (random.nextDouble() * 2 - 1) * (DefenseMap.halfHeight - 60),
        );
      }
      final radius = 16 + random.nextDouble() * 26;
      if (!_clear(position, radius) ||
          trees.any(
            (t) => t.position.distanceTo(position) < t.radius + radius,
          )) {
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
    }
  }

  void _buildHouses(Random random) {
    var attempts = 0;
    while (obstacles.length < 5 && attempts < 600) {
      attempts++;
      final position = Vector2(
        (random.nextDouble() * 2 - 1) * (DefenseMap.halfWidth - 100),
        (random.nextDouble() * 2 - 1) * (DefenseMap.halfHeight - 100),
      );
      final size = Vector2(
        60 + random.nextDouble() * 40,
        50 + random.nextDouble() * 30,
      );
      final reach = size.length / 2;
      if (!_clear(position, reach) ||
          trees.any(
            (t) => t.position.distanceTo(position) < t.radius + reach,
          ) ||
          obstacles.any((o) => o.position.distanceTo(position) < 200)) {
        continue;
      }
      final house = Building(
        index: obstacles.length,
        position: position,
        size: size,
        theme: theme,
      );
      obstacles.add(house);
      add(house);
    }
  }
}

/// The river with its banks, below the road so the bridges lie on top.
class _River extends PositionComponent {
  _River({required this.map, required this.theme}) : super(priority: -16);

  final DefenseMap map;
  final MapTheme theme;
  double _time = 0;

  @override
  void update(double dt) {
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final line = Path()..moveTo(map.river.first.x, map.river.first.y);
    for (final point in map.river.skip(1)) {
      line.lineTo(point.x, point.y);
    }
    final ice = theme == MapTheme.winter;
    Paint stroke(double width, Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width
      ..color = color;
    canvas.drawPath(
      line,
      stroke(DefenseMap.riverHalfWidth * 2 + 18, const Color(0x664A3B22)),
    );
    canvas.drawPath(
      line,
      stroke(
        DefenseMap.riverHalfWidth * 2,
        ice ? const Color(0xFF6E8FA6) : const Color(0xFF2F5D7C),
      ),
    );
    canvas.drawPath(
      line,
      stroke(
        DefenseMap.riverHalfWidth * 1.1,
        ice ? const Color(0xFF8DB0C4) : const Color(0xFF3B7194),
      ),
    );
    // Ripples that drift downstream.
    final ripple = stroke(2, const Color(0x55FFFFFF));
    final shift = (_time * 30) % 90;
    for (var i = 0; i < map.river.length - 1; i++) {
      final a = map.river[i];
      final b = map.river[i + 1];
      final along = b - a;
      final length = along.length;
      if (length == 0) {
        continue;
      }
      final dir = along / length;
      final side = Vector2(-dir.y, dir.x);
      for (var d = shift; d < length; d += 90) {
        for (final lane in const [-0.45, 0.1, 0.55]) {
          final at = a + dir * (d + lane * 40) + side * (lane * 50);
          canvas.drawLine(
            (at - dir * 9).toOffset(),
            (at + dir * 9).toOffset(),
            ripple,
          );
        }
      }
    }
  }
}

/// Planks across the water with a rail on either side.
void _drawBridge(Canvas canvas, Bridge bridge) {
  canvas.save();
  canvas.translate(bridge.centre.x, bridge.centre.y);
  canvas.rotate(bridge.angle);
  final deck = Rect.fromCenter(
    center: Offset.zero,
    width: bridge.halfLength * 2,
    height: bridge.halfWidth * 2,
  );
  canvas.drawRect(
    deck.shift(const Offset(3, 5)),
    Paint()..color = const Color(0x66000000),
  );
  canvas.drawRect(deck, Paint()..color = const Color(0xFF7A5C3A));
  final plank = Paint()
    ..strokeWidth = 1.5
    ..color = const Color(0xFF4E3A24);
  for (var x = deck.left + 8; x < deck.right; x += 9) {
    canvas.drawLine(Offset(x, deck.top), Offset(x, deck.bottom), plank);
  }
  final rail = Paint()
    ..strokeWidth = 5
    ..color = const Color(0xFF3B2B1A);
  canvas.drawLine(deck.topLeft, deck.topRight, rail);
  canvas.drawLine(deck.bottomLeft, deck.bottomRight, rail);
  final post = Paint()..color = rail.color;
  for (var x = deck.left; x <= deck.right + 0.1; x += bridge.halfLength / 2) {
    canvas.drawCircle(Offset(x, deck.top), 3.5, post);
    canvas.drawCircle(Offset(x, deck.bottom), 3.5, post);
  }
  canvas.restore();
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
    for (final bridge in map.bridges) {
      _drawBridge(canvas, bridge);
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
