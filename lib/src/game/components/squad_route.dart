import 'dart:math';

import 'package:flame/components.dart';

import '../game_config.dart';
import 'soldier.dart';

/// Where a squad on foot is at any second of the round clock. Every client
/// works it out the same way: a patrol from the seed while nothing happens,
/// and the orders its commander sent ([order]) when it stalks an enemy. So
/// no positions travel, only an order now and then.
class SquadRoute {
  SquadRoute({
    required this.key,
    required this.ownerId,
    required Vector2 start,
    required this.startAt,
    required this.walkable,
  }) {
    _legs.add(_Leg(startAt, start.clone(), null, _patrol(start, 0)));
  }

  /// Round clock second the squad sets off.
  final double startAt;

  /// The squad's name on the wire.
  final String key;

  /// Who the squad fights for, null for bystanders that only walk.
  final String? ownerId;

  /// Whether a patrol may lead to a point: on the field, out of the water.
  final bool Function(Vector2 point) walkable;

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
      _legs[i] = _Leg(
        leg.at,
        from,
        leg.to,
        leg.to == null ? _patrol(from, i) : const [],
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
        if (walkable(candidate)) {
          point = candidate;
        }
      }
      points.add(point ?? around.clone());
    }
    return points;
  }
}

/// From [at] on the squad walks from [from] to [to], or with [to] null
/// round the [loop] of a patrol.
class _Leg {
  const _Leg(this.at, this.from, this.to, this.loop);

  final double at;
  final Vector2 from;
  final Vector2? to;
  final List<Vector2> loop;

  Vector2 position(double seconds) {
    final target = to;
    if (target != null) {
      final offset = target - from;
      final length = offset.length;
      final walked = seconds * GameConfig.stalkSpeed;
      return walked >= length
          ? target.clone()
          : from + offset * (walked / length);
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
