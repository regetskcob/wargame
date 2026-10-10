import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../game_config.dart';
import '../components/tree.dart';
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

  /// The base of every side, the left one first. A common round has one.
  late final List<Headquarters> bases;

  /// The base of a common round, the left one of a duel.
  Headquarters get headquarters => bases.first;

  /// The base of [lane].
  Headquarters baseOf(int lane) => bases[lane.clamp(0, bases.length - 1)];

  /// Woods along the road, numbered like those of the open field so shots
  /// that cut them down travel the same way.
  final trees = <Tree>[];

  /// Farm houses that give cover, numbered like the open field's buildings.
  final obstacles = <Obstacle>[];

  Tree? treeAt(int index) =>
      index >= 0 && index < trees.length ? trees[index] : null;

  Obstacle? obstacleAt(int index) =>
      index >= 0 && index < obstacles.length ? obstacles[index] : null;

  bool _clear(Vector2 position, double radius) =>
      DefenseMap.bounds.deflate(50).contains(position.toOffset()) &&
      map.distanceToRoad(position) > DefenseMap.roadHalfWidth + radius + 40 &&
      map.distanceToRiver(position) > DefenseMap.riverHalfWidth + radius + 16 &&
      map.bases.every((base) => position.distanceTo(base) > 260) &&
      position.distanceTo(map.outpost) > 90 + radius &&
      !map.bridges.any(
        (b) => b.centre.distanceTo(position) < b.halfLength + radius + 30,
      );

  /// River and road lie in the world itself, under the soldiers and the
  /// tracks. As children of the field they would be drawn at the field's
  /// own place in the world, over everything that walks on the road.
  late final _ground = _Ground(map: map, theme: theme);

  @override
  void onMount() {
    super.onMount();
    parent?.add(_ground);
  }

  @override
  void onRemove() {
    _ground.removeFromParent();
    super.onRemove();
  }

  @override
  void onLoad() {
    bases = [
      for (final (lane, side) in map.lanes.indexed)
        Headquarters(
          position: side.base.clone(),
          approach: (side.road[side.road.length - 2] - side.base).normalized(),
          lane: lane,
        ),
    ];
    bases.forEach(add);
    // In a duel the other side's base stands where the enemy rolls in.
    if (!map.duel) {
      add(
        EnemyOutpost(
          position: map.outpost.clone(),
          facing: (map.road[0] - map.outpost).normalized(),
        ),
      );
    }
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
      final tree = Tree(
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
/// River and road of the field, below soldiers (-12) and tracks (-15).
class _Ground extends Component {
  _Ground({required DefenseMap map, required MapTheme theme})
    : super(priority: -17) {
    add(_River(map: map, theme: theme));
    add(_Road(map: map, theme: theme));
  }
}

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

    final line = Path();
    for (final road in map.roads) {
      line.moveTo(road.first.x, road.first.y);
      for (final point in road.skip(1)) {
        line.lineTo(point.x, point.y);
      }
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
    for (final (road, i) in [
      for (final road in map.roads)
        for (var i = 0; i < road.length - 1; i++) (road, i),
    ]) {
      final a = road[i];
      final b = road[i + 1];
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
  Headquarters({required super.position, Vector2? approach, this.lane = 0})
    : approach = approach ?? Vector2(-1, 0),
      super(
        size: Vector2.all(DefenseMap.baseRadius * 2),
        anchor: Anchor.center,
        priority: 4,
      );

  /// Direction from the base to where the road comes in, kept free for the
  /// gate.
  final Vector2 approach;

  /// The side whose base it is in a duel, 0 in a common round.
  final int lane;

  double hp = GameConfig.baseHp;

  /// Watchtower, barracks or fortress, see [GameConfig.hqNames].
  int level = 1;
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

  /// The grounds around the bunker: a fence with barracks once the base has
  /// grown, a wall with corner towers for the fortress. The gate faces the
  /// road.
  void _renderGrounds(Canvas canvas, Offset c) {
    if (level < 2) {
      return;
    }
    final fortress = level >= 3;
    final reach = fortress ? 200.0 : 150.0;
    final gate = atan2(approach.y, approach.x);
    canvas.drawCircle(
      c,
      reach,
      Paint()
        ..color = fortress ? const Color(0x33C8B68A) : const Color(0x22C8B68A),
    );
    // Fence posts or wall, open where the road comes in.
    final wall = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = fortress ? 12 : 4
      ..color = fortress ? const Color(0xFF8D8678) : const Color(0xFF6E5A3A);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: reach),
      gate + 0.35,
      2 * pi - 0.7,
      false,
      wall,
    );
    if (!fortress) {
      for (var i = 0; i < 28; i++) {
        final a = gate + 0.35 + (2 * pi - 0.7) * i / 27;
        canvas.drawCircle(
          c + Offset(cos(a), sin(a)) * reach,
          3,
          Paint()..color = const Color(0xFF4A3B26),
        );
      }
    }
    // Barracks: long huts on both sides, away from the gate.
    final huts = fortress
        ? [pi * 0.5, pi, pi * 1.5, pi * 0.75, pi * 1.25]
        : [pi * 0.6, pi * 1.4];
    for (final offset in huts) {
      final a = gate + offset;
      final at = c + Offset(cos(a), sin(a)) * (reach * 0.62);
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(a + pi / 2);
      final hut = Rect.fromCenter(center: Offset.zero, width: 58, height: 26);
      canvas.drawRect(
        hut.shift(const Offset(3, 4)),
        Paint()..color = const Color(0x55000000),
      );
      canvas.drawRect(hut, Paint()..color = const Color(0xFF6B7457));
      canvas.drawLine(
        Offset(hut.left, 0),
        Offset(hut.right, 0),
        Paint()
          ..strokeWidth = 2
          ..color = const Color(0xFF3E4532),
      );
      canvas.drawRect(
        hut,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF2B3320),
      );
      canvas.restore();
    }
    if (fortress) {
      // Towers where the wall meets the gate and around the back.
      for (final offset in [0.35, -0.35, pi * 0.66, -pi * 0.66, pi]) {
        final a = gate + offset;
        final at = c + Offset(cos(a), sin(a)) * reach;
        final tower = Rect.fromCenter(center: at, width: 28, height: 28);
        canvas.drawRect(tower, Paint()..color = const Color(0xFF6F6A5E));
        canvas.drawRect(
          tower,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFF2E2B25),
        );
        canvas.drawCircle(at, 5, Paint()..color = GameConfig.teamColors[1]);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    const r = DefenseMap.baseRadius;
    _renderGrounds(canvas, c);
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

    final ratio = (hp / GameConfig.baseMaxHp(level)).clamp(0.0, 1.0);
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

/// The enemy's outpost beside the start of the road, where tanks and squads
/// roll out from: a watchtower on a sandbagged square under the enemy's
/// flag. Only scenery.
class EnemyOutpost extends PositionComponent {
  EnemyOutpost({required super.position, required this.facing})
    : super(size: Vector2.all(80), anchor: Anchor.center, priority: 4);

  /// Direction to the road, where the gate opens.
  final Vector2 facing;

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    final enemy = GameConfig.teamColors[2];
    canvas.drawCircle(c, 40, Paint()..color = const Color(0x33000000));
    // Sandbag ring, open towards the road.
    final gate = atan2(facing.y, facing.x);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: 34),
      gate + 0.5,
      2 * pi - 1,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..color = const Color(0xFF9C8A62),
    );
    // Watchtower on four legs with a roof.
    final tower = Rect.fromCenter(center: c, width: 30, height: 30);
    canvas.drawRect(
      tower.shift(const Offset(4, 5)),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawRect(tower, Paint()..color = const Color(0xFF4A4A52));
    canvas.drawRect(
      tower,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF1E1E24),
    );
    canvas.drawLine(
      tower.topLeft,
      tower.bottomRight,
      Paint()
        ..strokeWidth = 2
        ..color = const Color(0xFF1E1E24),
    );
    canvas.drawLine(
      tower.topRight,
      tower.bottomLeft,
      Paint()
        ..strokeWidth = 2
        ..color = const Color(0xFF1E1E24),
    );
    canvas.drawCircle(c, 6, Paint()..color = enemy);
    // The enemy's flag.
    final pole = c + const Offset(10, -8);
    canvas.drawLine(
      pole,
      pole + const Offset(0, -40),
      Paint()
        ..strokeWidth = 3
        ..color = const Color(0xFF2E221A),
    );
    canvas.drawRect(
      Rect.fromLTWH(pole.dx, pole.dy - 40, 24, 14),
      Paint()..color = enemy,
    );
  }
}
