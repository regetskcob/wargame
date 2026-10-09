import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../components/tank_painter.dart';
import '../game_config.dart';
import '../../l10n/l10n.dart';

/// The fixed battlefield of a defense round: a rectangle, one road the enemy
/// follows and the base at its end. Which of the layouts is used follows from
/// the round seed, so every client draws the same one.
///
/// A duel has two roads, one to each player's base. Each is a [lanes] map of
/// its own, with its [road] and [base], sharing the river, the bridges and
/// [roads], so the enemies, the soldiers and the aircraft of a lane follow
/// it as they follow the one road of a common round.
class DefenseMap {
  DefenseMap._(
    this.road,
    this.river,
    List<Vector2> extraBridges, {
    List<List<Vector2>>? roads,
    List<Bridge>? bridges,
  }) : roads = roads ?? [road] {
    this.bridges =
        bridges ??
        [
          ..._crossings(),
          for (final at in extraBridges)
            Bridge(
              centre: at,
              along: _riverNormalAt(at),
              halfLength: _bridgeHalf,
            ),
        ];
  }

  factory DefenseMap.forSeed(int seed) {
    final layout = _layouts[layoutFor(seed)];
    return DefenseMap._(layout.road, layout.river, layout.bridges);
  }

  /// The duel's field: a layout of a common round, with a base at either
  /// end of its road. Every road runs from the left to the right of the
  /// field: the left player's base stands where the enemy used to roll in,
  /// the right player's where the base always stands. Each side's waves
  /// roll along the road to the other's base, so they meet on the way.
  factory DefenseMap.duelForSeed(int seed) {
    final layout = _layouts[layoutFor(seed)];
    final whole = DefenseMap._(layout.road, layout.river, layout.bridges);
    // The far end comes in off the edge, so the base stands on the field.
    final (start, _) = whole.alongRoad(_duelInset);
    final (_, segment) = whole.pointAlong(_duelInset);
    final toRight = [start, ...layout.road.skip(segment + 1)];
    final toLeft = toRight.reversed.toList();
    DefenseMap side(List<Vector2> road) => DefenseMap._(
      road,
      layout.river,
      const [],
      roads: [toRight],
      bridges: whole.bridges,
    );
    // Lane 0 is the road to the left base, the red player's.
    final left = side(toLeft);
    final right = side(toRight);
    left.lanes = [left, right];
    right.lanes = left.lanes;
    return left;
  }

  /// How far in from the edge the left player's base stands in a duel.
  static const _duelInset = 230.0;

  /// Every road on the field: one, or one per side in a duel.
  final List<List<Vector2>> roads;

  /// The map of each side's road and base, in the order of the players the
  /// round start names. Just this one outside a duel.
  late List<DefenseMap> lanes = [this];

  bool get duel => lanes.length > 1;

  /// Every base on the field, one per lane.
  List<Vector2> get bases => [for (final lane in lanes) lane.base];

  /// Which of the layouts a round seed picks.
  static int layoutFor(int seed) => (seed ~/ 4).abs() % _layouts.length;

  static int get layoutCount => _layouts.length;

  static const halfWidth = 1100.0;
  static const halfHeight = 700.0;
  static const roadHalfWidth = 42.0;
  static const baseRadius = 70.0;

  /// Half the width of the river. Tanks and soldiers cross it on bridges
  /// only, shells, grenades and everything that flies go over it.
  static const riverHalfWidth = 46.0;
  static const _bridgeHalf = riverHalfWidth + 22;
  static const bridgeHalfWidth = roadHalfWidth + 8;

  static final bounds = Rect.fromLTRB(
    -halfWidth,
    -halfHeight,
    halfWidth,
    halfHeight,
  );

  static final _layouts = <_Layout>[
    _Layout(
      road: [
        Vector2(-halfWidth, -450),
        Vector2(-620, -450),
        Vector2(-620, 400),
        Vector2(-60, 400),
        Vector2(-60, -420),
        Vector2(520, -420),
        Vector2(520, 160),
        Vector2(860, 160),
      ],
      river: [
        Vector2(-300, -halfHeight - 40),
        Vector2(-360, -300),
        Vector2(-310, 100),
        Vector2(-370, halfHeight + 40),
      ],
      bridges: [Vector2(-335, -120)],
    ),
    _Layout(
      road: [
        Vector2(-halfWidth, 460),
        Vector2(-720, 460),
        Vector2(-720, -440),
        Vector2(-220, -440),
        Vector2(-220, 440),
        Vector2(300, 440),
        Vector2(300, -200),
        Vector2(860, -200),
      ],
      river: [
        Vector2(-halfWidth - 40, 30),
        Vector2(-500, -20),
        Vector2(0, 50),
        Vector2(600, 10),
        Vector2(halfWidth + 40, 40),
      ],
      bridges: [Vector2(700, 20)],
    ),
    _Layout(
      road: [
        Vector2(-880, -halfHeight),
        Vector2(-880, 320),
        Vector2(-380, 320),
        Vector2(-380, -360),
        Vector2(200, -360),
        Vector2(200, 360),
        Vector2(860, 360),
        Vector2(860, 0),
      ],
      river: [
        Vector2(-60, -halfHeight - 40),
        Vector2(-120, -200),
        Vector2(-40, 300),
        Vector2(-100, halfHeight + 40),
      ],
      bridges: [Vector2(-60, 200)],
    ),
    // Through the river four times, a winding road with a bridge on each
    // crossing.
    _Layout(
      road: [
        Vector2(-halfWidth, 20),
        Vector2(-760, 20),
        Vector2(-760, -500),
        Vector2(-300, -500),
        Vector2(-300, 480),
        Vector2(260, 480),
        Vector2(260, -460),
        Vector2(780, -460),
        Vector2(780, 220),
      ],
      river: [
        Vector2(-halfWidth - 40, -60),
        Vector2(-500, -160),
        Vector2(0, -80),
        Vector2(500, -170),
        Vector2(halfWidth + 40, -100),
      ],
      bridges: const [],
    ),
  ];

  /// Waypoints from where the enemy rolls in to the base.
  final List<Vector2> road;

  /// Centre line of the river, running from one edge of the field to another.
  final List<Vector2> river;

  /// Where tanks get across: every crossing of the road and a few more.
  late final List<Bridge> bridges;

  Vector2 get entry => road.first;
  Vector2 get base => road.last;

  /// Shortest distance from [point] to the centre line of any road.
  double distanceToRoad(Vector2 point) {
    var best = double.infinity;
    for (final road in roads) {
      for (var i = 0; i < road.length - 1; i++) {
        best = min(best, _distanceToSegment(point, road[i], road[i + 1]));
      }
    }
    return best;
  }

  /// Shortest distance from [point] to the river's centre line.
  double distanceToRiver(Vector2 point) {
    var best = double.infinity;
    for (var i = 0; i < river.length - 1; i++) {
      best = min(best, _distanceToSegment(point, river[i], river[i + 1]));
    }
    return best;
  }

  /// Whether a tank or soldier at [point] would stand in the water, that is
  /// in the river and on none of the bridges. [margin] widens the river.
  bool inWater(Vector2 point, {double margin = 0}) {
    if (distanceToRiver(point) > riverHalfWidth + margin) {
      return false;
    }
    return !bridges.any((bridge) => bridge.carries(point));
  }

  Bridge? bridgeAt(Vector2 point) {
    for (final bridge in bridges) {
      if (bridge.carries(point)) {
        return bridge;
      }
    }
    return null;
  }

  /// The roads' crossings of the river, each with a bridge along the road.
  List<Bridge> _crossings() {
    final found = <Bridge>[];
    for (final road in roads) {
      _crossingsOf(road, found);
    }
    return found;
  }

  void _crossingsOf(List<Vector2> road, List<Bridge> found) {
    for (var i = 0; i < road.length - 1; i++) {
      for (var j = 0; j < river.length - 1; j++) {
        final at = _intersect(road[i], road[i + 1], river[j], river[j + 1]);
        if (at != null) {
          found.add(
            Bridge(
              centre: at,
              along: (road[i + 1] - road[i]).normalized(),
              halfLength: _bridgeHalf + 12,
            ),
          );
        }
      }
    }
  }

  /// Direction across the river at [at], for a bridge that is not on the road.
  Vector2 _riverNormalAt(Vector2 at) {
    var best = double.infinity;
    var normal = Vector2(1, 0);
    for (var i = 0; i < river.length - 1; i++) {
      final distance = _distanceToSegment(at, river[i], river[i + 1]);
      if (distance < best) {
        best = distance;
        final dir = (river[i + 1] - river[i]).normalized();
        normal = Vector2(-dir.y, dir.x);
      }
    }
    return normal;
  }

  static Vector2? _intersect(Vector2 a, Vector2 b, Vector2 c, Vector2 d) {
    final r = b - a;
    final s = d - c;
    final denominator = r.cross(s);
    if (denominator.abs() < 1e-9) {
      return null;
    }
    final t = (c - a).cross(s) / denominator;
    final u = (c - a).cross(r) / denominator;
    if (t < 0 || t > 1 || u < 0 || u > 1) {
      return null;
    }
    return a + r * t;
  }

  /// Length of the road from where the enemy rolls in to the base.
  late final double roadLength = () {
    var total = 0.0;
    for (var i = 0; i < road.length - 1; i++) {
      total += road[i].distanceTo(road[i + 1]);
    }
    return total;
  }();

  /// The point [distance] along the road and the direction it runs there.
  (Vector2, Vector2) alongRoad(double distance) {
    var left = distance;
    for (var i = 0; i < road.length - 1; i++) {
      final a = road[i];
      final b = road[i + 1];
      final length = a.distanceTo(b);
      final dir = length == 0 ? Vector2(1, 0) : (b - a) / length;
      if (left <= length || i == road.length - 2) {
        return (a + dir * min(left, length), dir);
      }
      left -= length;
    }
    return (road.last.clone(), Vector2(1, 0));
  }

  static double _distanceToSegment(Vector2 p, Vector2 a, Vector2 b) {
    final ab = b - a;
    final length2 = ab.length2;
    if (length2 == 0) {
      return p.distanceTo(a);
    }
    final t = ((p - a).dot(ab) / length2).clamp(0.0, 1.0);
    return p.distanceTo(a + ab * t);
  }

  /// Why a gun can not go to [point], or null when it can.
  String? whyNotBuild(Vector2 point, Iterable<Vector2> towers) {
    if (!bounds.deflate(40).contains(point.toOffset())) {
      return tr('Zu nah am Rand', 'Too close to the edge');
    }
    if (distanceToRoad(point) < roadHalfWidth + 30) {
      return tr('Nicht auf der Straße', 'Not on the road');
    }
    if (inWater(point, margin: 26) ||
        bridges.any((b) => b.centre.distanceTo(point) < b.halfLength + 30)) {
      return tr('Nicht im Fluss', 'Not in the river');
    }
    if (bases.any((base) => point.distanceTo(base) < baseRadius + 50)) {
      return tr('Zu nah am Stützpunkt', 'Too close to the base');
    }
    if (towers.any((t) => t.distanceTo(point) < GameConfig.towerSpacing)) {
      return tr('Zu nah am nächsten Geschütz', 'Too close to the next turret');
    }
    return null;
  }

  /// Where the players start: in a column in front of the base, off the road.
  Vector2 spawnFor(int slot, int count) {
    final spread = (slot - (count - 1) / 2) * 70;
    final candidates = [
      base + Vector2(-170, spread),
      base + Vector2(spread, -170),
      base + Vector2(spread, 170),
    ];
    for (final at in candidates) {
      if (bounds.deflate(40).contains(at.toOffset()) &&
          distanceToRoad(at) > roadHalfWidth + 20 &&
          !inWater(at, margin: GameConfig.tankRadius + 10)) {
        return at;
      }
    }
    return candidates.first;
  }

  /// The point [distance] along the road from the entry and the index of the
  /// segment it lies on.
  (Vector2, int) pointAlong(double distance) {
    var left = distance;
    for (var i = 0; i < road.length - 1; i++) {
      final length = road[i].distanceTo(road[i + 1]);
      if (left <= length || i == road.length - 2) {
        final t = length == 0 ? 0.0 : (left / length).clamp(0.0, 1.0);
        return (road[i] + (road[i + 1] - road[i]) * t, i);
      }
      left -= length;
    }
    return (road.last.clone(), road.length - 2);
  }

  /// Share of the road, counted from the entry, where the comrade in [slot]
  /// keeps watch: spread out so they meet the enemy one after the other,
  /// the first close to the base.
  static const _postShares = [0.78, 0.58, 0.4, 0.66, 0.5];

  /// Where along the road the comrade in [slot] stops and the spot on the
  /// shoulder it takes: close enough to fire on everything that passes, out
  /// of the way of the tanks on the road and dry, away from the river.
  late final List<(double, Vector2)> _allyPlaces = [
    for (var slot = 0; slot < _postShares.length; slot++) _placeAlly(slot),
  ];

  (double, Vector2) _placeAlly(int slot) {
    const offset = roadHalfWidth + 24;
    final sides = slot.isEven ? [1.0, -1.0] : [-1.0, 1.0];
    final base = _postShares[slot];
    for (final nudge in const [0.0, 0.04, -0.04, 0.08, -0.08, 0.12, -0.12]) {
      final share = (base + nudge).clamp(0.05, 0.92);
      final (point, segment) = pointAlong(roadLength * share);
      final along = (road[segment + 1] - road[segment]).normalized();
      final side = Vector2(-along.y, along.x);
      for (final sign in sides) {
        final at = point + side * (offset * sign);
        if (bounds.deflate(40).contains(at.toOffset()) &&
            distanceToRoad(at) > roadHalfWidth + 15 &&
            !inWater(at, margin: GameConfig.tankRadius + 10) &&
            bridges.every((b) => b.centre.distanceTo(at) > b.halfLength + 30)) {
          return (share, at);
        }
      }
    }
    final (point, _) = pointAlong(roadLength * base);
    return (base, point);
  }

  Vector2 allyPost(int slot) =>
      _allyPlaces[slot % _allyPlaces.length].$2.clone();

  /// The way from the base to the post of [slot]: back up the road to the
  /// spot next to the post, then off onto the shoulder. On the road the
  /// comrades never run into the woods and cross the river on the bridges.
  List<Vector2> allyRoute(int slot) {
    final (share, post) = _allyPlaces[slot % _allyPlaces.length];
    final (point, segment) = pointAlong(roadLength * share);
    return [
      for (var i = road.length - 2; i > segment; i--) road[i].clone(),
      point,
      post.clone(),
    ];
  }

  /// The enemy's outpost: beside the start of the road, where the waves
  /// roll out from. Only scenery, it cannot be attacked.
  late final Vector2 outpost = () {
    final along = (road[1] - road[0]).normalized();
    final side = Vector2(-along.y, along.x);
    final ahead = road[0] + along * 110;
    for (final sign in const [1.0, -1.0]) {
      final at = ahead + side * (sign * (roadHalfWidth + 62));
      if (bounds.deflate(50).contains(at.toOffset()) &&
          !inWater(at, margin: 50)) {
        return at;
      }
    }
    return ahead + side * (roadHalfWidth + 62);
  }();

  /// The vehicle of the comrade in [slot].
  static TankType allyType(int slot) => const [
    TankType.keiler,
    TankType.hermelin,
    TankType.habicht,
    TankType.keiler,
    TankType.fuchs,
  ][slot % 5];

  /// The enemy for slot [n] of wave [wave]: more and heavier tanks later on.
  static TankType enemyType(int wave, int n) {
    final roll = (wave * 7 + n * 13) % 10;
    if (wave >= 7 && roll < 2) {
      return TankType.auerochse;
    }
    if (wave >= 4 && roll == 9) {
      return TankType.dachs;
    }
    if (wave >= 5 && roll < 3) {
      return TankType.keiler;
    }
    if (wave >= 3 && roll < 6) {
      return TankType.habicht;
    }
    return roll.isEven ? TankType.fuchs : TankType.hermelin;
  }

  /// Number of enemy tanks in [wave].
  static int waveSize(int wave) => 3 + 2 * wave;

  /// Everything else a wave brings: squads on foot along the road, attack
  /// helicopters, jets that bomb the base and kamikaze drones. Only the
  /// tanks come in the first wave, the air shows up from the second on, so
  /// flak and the Habicht earn their keep.
  static WavePlan planFor(int wave) => WavePlan(
    tanks: waveSize(wave),
    squads: 1 + wave ~/ 3,
    helicopters: wave >= 2 ? 1 + (wave - 2) ~/ 3 : 0,
    jets: wave >= 3 ? 1 + (wave - 3) ~/ 3 : 0,
    drones: wave >= 4 ? (wave - 2) ~/ 2 : 0,
  );
}

/// What a wave of a defense round is made of.
class WavePlan {
  const WavePlan({
    required this.tanks,
    required this.squads,
    required this.helicopters,
    required this.jets,
    required this.drones,
  });

  final int tanks;
  final int squads;
  final int helicopters;
  final int jets;
  final int drones;

  int get total => tanks + squads + helicopters + jets + drones;
}

/// A wooden bridge over the river, a rectangle turned to run [along].
class Bridge {
  Bridge({
    required this.centre,
    required this.along,
    required this.halfLength,
    this.halfWidth = DefenseMap.bridgeHalfWidth,
  });

  final Vector2 centre;
  final Vector2 along;
  final double halfLength;
  final double halfWidth;

  double get angle => atan2(along.y, along.x);

  bool carries(Vector2 point) {
    final offset = point - centre;
    final a = offset.dot(along);
    final side = offset.x * -along.y + offset.y * along.x;
    return a.abs() <= halfLength && side.abs() <= halfWidth;
  }
}

class _Layout {
  const _Layout({
    required this.road,
    required this.river,
    required this.bridges,
  });

  final List<Vector2> road;
  final List<Vector2> river;
  final List<Vector2> bridges;
}
