import 'dart:math';

import 'package:flame/components.dart';

import '../game_config.dart';
import 'soldier.dart';

/// Where a squad on foot is at any second of the round clock. Every client
/// works it out the same way: a patrol from the seed while nothing happens,
/// and the orders its commander sent ([order]) when it stalks an enemy. So
/// no positions travel, only an order now and then.
///
/// A squad walks in straight lines, so every line is checked along its
/// length, not only where it ends: a patrol keeps to points it reaches dry,
/// and an order across the water goes over a bridge ([crossings]), or stops
/// at the shore when there is none. Before, only the ends were checked, and
/// squads walked through the river of the defense map.
class SquadRoute {
  SquadRoute({
    required this.key,
    required this.ownerId,
    required Vector2 start,
    required this.startAt,
    required this.walkable,
    bool Function(Vector2 point)? onLand,
    this.crossings = const [],
  }) : onLand = onLand ?? walkable {
    _legs.add(_Leg(startAt, start.clone(), null, _patrol(start, 0)));
  }

  /// The bridges a squad may cross the water on, each as the two ends of
  /// its deck.
  final List<(Vector2, Vector2)> crossings;

  /// How far apart the points are at which a line is checked: less than
  /// the narrowest stretch of water or the smallest house.
  static const _step = 12.0;

  /// How far beyond a bridge's end a squad lines up to cross it, so it
  /// walks onto the deck along the road and not in from the side.
  static const _approach = 40.0;

  /// Round clock second the squad sets off.
  final double startAt;

  /// The squad's name on the wire.
  final String key;

  /// Who the squad fights for, null for bystanders that only walk.
  final String? ownerId;

  /// Whether a patrol may lead to a point: on the field, out of the water.
  final bool Function(Vector2 point) walkable;

  /// Whether a soldier may stand at a point: out of the water, houses
  /// aside. Cheaper than [walkable], so it can be asked every frame.
  final bool Function(Vector2 point) onLand;

  /// Whether the straight line from [from] to [to] stays walkable.
  bool clear(Vector2 from, Vector2 to) {
    final steps = (from.distanceTo(to) / _step).ceil();
    for (var i = 1; i <= steps; i++) {
      if (!walkable(from + (to - from) * (i / steps))) {
        return false;
      }
    }
    return true;
  }

  /// The way from [from] to [to]: straight when nothing is in the way,
  /// else over the bridge that makes it shortest, else as far as the
  /// shore.
  List<Vector2> _wayTo(Vector2 from, Vector2 to) {
    if (clear(from, to)) {
      return [to.clone()];
    }
    List<Vector2>? best;
    var bestLength = double.infinity;
    for (final (a, b) in crossings) {
      final along = (b - a).normalized();
      for (final (near, far) in [
        (a - along * _approach, b + along * _approach),
        (b + along * _approach, a - along * _approach),
      ]) {
        if (!clear(from, near) || !clear(near, far) || !clear(far, to)) {
          continue;
        }
        final length =
            from.distanceTo(near) + near.distanceTo(far) + far.distanceTo(to);
        if (length < bestLength) {
          bestLength = length;
          best = [near, far, to.clone()];
        }
      }
    }
    if (best != null) {
      return best;
    }
    // No bridge leads there: up to the last dry step towards it.
    final steps = (from.distanceTo(to) / _step).ceil();
    var shore = from.clone();
    for (var i = 1; i <= steps; i++) {
      final next = from + (to - from) * (i / steps);
      if (!walkable(next)) {
        break;
      }
      shore = next;
    }
    return [shore];
  }

  final _legs = <_Leg>[];

  /// The soldiers of the squad, the fallen included.
  final members = <Soldier>[];

  /// Whether anybody of the squad still stands.
  bool get alive => members.any((soldier) => !soldier.dead);

  /// When the last order was given, on the round clock, null before the
  /// first.
  double? get orderedAt => _ordered ? _legs.last.at : null;
  bool _ordered = false;

  /// Where the last order sends the squad, null while it patrols.
  Vector2? get goal => _legs.last.to;

  bool get stalking => goal != null;

  /// Where the squad stands at [t].
  Vector2 at(double t) {
    var leg = _legs.first;
    for (final next in _legs) {
      if (next.at > t) {
        break;
      }
      leg = next;
    }
    return leg.position(max(0, t - leg.at));
  }

  /// The commander's order from [t] on: walk to [to], or with [to] null
  /// patrol around where the squad stands then. A repeated order is
  /// ignored, one that comes in late is put in its place.
  void order(double t, Vector2? to) {
    if (_legs.any(
      (leg) =>
          leg.at == t &&
          (leg.to == null ? to == null : to != null && leg.to == to),
    )) {
      return;
    }
    var index = _legs.indexWhere((leg) => leg.at > t);
    if (index < 0) {
      index = _legs.length;
    }
    if (index == 0) {
      return;
    }
    _ordered = true;
    _legs.insert(index, _Leg(t, Vector2.zero(), to?.clone(), const []));
    // Every leg from the new one on starts where the one before left off.
    for (var i = index; i < _legs.length; i++) {
      final before = _legs[i - 1];
      final leg = _legs[i];
      final from = before.position(leg.at - before.at);
      final target = leg.to;
      _legs[i] = _Leg(
        leg.at,
        from,
        target,
        target == null ? _patrol(from, i) : _wayTo(from, target),
      );
    }
    // Only the last legs matter once the clock is past them.
    while (_legs.length > 4) {
      _legs.removeAt(0);
    }
  }

  /// A round of four points about [around], the same on every client.
  List<Vector2> _patrol(Vector2 around, int salt) {
    final random = Random(stableHash('$key/$salt'));
    final turn = random.nextDouble() * 2 * pi;
    final points = <Vector2>[];
    for (var i = 0; i < 4; i++) {
      Vector2? point;
      for (var attempt = 0; attempt < 6 && point == null; attempt++) {
        final angle = turn + i * pi / 2 + (random.nextDouble() - 0.5) * 0.8;
        final reach =
            GameConfig.patrolReach * (0.5 + random.nextDouble() * 0.5);
        final candidate = around + Vector2(cos(angle), sin(angle)) * reach;
        // Reached dry from the middle and from the point before, so the
        // round does not cut through the water or a house.
        if (walkable(candidate) &&
            clear(around, candidate) &&
            (points.isEmpty || clear(points.last, candidate))) {
          point = candidate;
        }
      }
      points.add(point ?? around.clone());
    }
    // The round closes from the last point back to the first.
    if (!clear(points.last, points.first)) {
      points.last = around.clone();
    }
    return points;
  }
}

/// From [at] on the squad walks from [from] to [to] along the points of
/// [loop] (the way, over a bridge if need be), or with [to] null round the
/// [loop] of a patrol.
class _Leg {
  const _Leg(this.at, this.from, this.to, this.loop);

  final double at;
  final Vector2 from;
  final Vector2? to;
  final List<Vector2> loop;

  Vector2 position(double seconds) {
    if (to != null) {
      var left = seconds * GameConfig.stalkSpeed;
      var here = from;
      for (final next in loop) {
        final length = here.distanceTo(next);
        if (left <= length) {
          return here + (next - here) * (length == 0 ? 0 : left / length);
        }
        left -= length;
        here = next;
      }
      return here.clone();
    }
    var left = seconds * GameConfig.patrolSpeed;
    var here = from;
    var next = loop.first;
    // First to the round, then round and round it.
    final approach = here.distanceTo(next);
    if (left <= approach) {
      return here + (next - here) * (approach == 0 ? 0 : left / approach);
    }
    left -= approach;
    var lap = 0.0;
    for (var i = 0; i < loop.length; i++) {
      lap += loop[i].distanceTo(loop[(i + 1) % loop.length]);
    }
    if (lap > 0) {
      left %= lap;
    }
    for (var i = 0; i < loop.length; i++) {
      here = loop[i];
      next = loop[(i + 1) % loop.length];
      final length = here.distanceTo(next);
      if (left <= length) {
        return here + (next - here) * (length == 0 ? 0 : left / length);
      }
      left -= length;
    }
    return loop.first.clone();
  }
}
