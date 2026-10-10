import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../l10n/l10n.dart';
import '../flag_match.dart';
import '../game_config.dart';
import 'cover_field.dart';
import 'explosion.dart';

/// What a depot hands out to a tank that parks on it.
enum DepotKind {
  fuel,
  ammo;

  String get label => switch (this) {
    DepotKind.fuel => tr('TANKSTELLE', 'FUEL STATION'),
    DepotKind.ammo => tr('MUNITIONSDEPOT', 'AMMO DEPOT'),
  };

  Color get color => switch (this) {
    DepotKind.fuel => const Color(0xFFFF9100),
    DepotKind.ammo => const Color(0xFF4FC3F7),
  };
}

/// Where a depot stands and who it belongs to, before it is built.
typedef DepotSpot = ({DepotKind kind, int team, Vector2 position});

/// A fuel station or ammunition depot. A tank that stands still on the pad
/// fills up bit by bit. Shells and blasts wear the core in the middle down;
/// once it goes up it takes the tanks around it along and stands again after
/// [GameConfig.depotRebuildSeconds]. Team depots of capture the flag serve
/// only their own side and only the other side can shoot them.
class SupplyDepot extends PositionComponent {
  SupplyDepot({
    required this.index,
    required this.kind,
    required this.team,
    required super.position,
  }) : super(
         size: Vector2.all(GameConfig.depotRadius * 2),
         anchor: Anchor.center,
         priority: -9,
       );

  /// Position in the field, identical on every client for a given round.
  final int index;
  final DepotKind kind;

  /// 0 for a depot anybody may use and shoot, else the owning team.
  final int team;

  double hp = GameConfig.depotHp;
  double _rebuild = 0;
  double _time = 0;
  double _flash = 0;

  /// Set every frame while the local tank fills up here, for the pulse.
  bool filling = false;

  late final CircleHitbox _core;

  bool get destroyed => hp <= 0;

  /// Share of the way to standing again, 0 right after it went up.
  double get rebuildShare =>
      destroyed ? 1 - _rebuild / GameConfig.depotRebuildSeconds : 1;

  /// Whether [point] lies on the pad.
  bool covers(Vector2 point) =>
      point.distanceTo(position) < GameConfig.depotRadius;

  /// Whether a tank of [tankTeam] may fill up here.
  bool serves(int tankTeam) => !destroyed && (team == 0 || team == tankTeam);

  @override
  void onLoad() {
    _core = CircleHitbox(
      radius: GameConfig.depotCoreRadius,
      position: size / 2,
      anchor: Anchor.center,
    );
    add(_core);
  }

  /// Applies [value] as the new health. Returns true when it went up. A
  /// depot that is down and gets a health above zero, from a client that
  /// rebuilt it a moment earlier, stands again.
  bool setHp(double value) {
    final wasDown = destroyed;
    if (value < hp) {
      _flash = 0.12;
    }
    hp = value.clamp(0.0, GameConfig.depotHp);
    if (wasDown && hp > 0) {
      _rebuild = 0;
      _core.collisionType = CollisionType.active;
      return false;
    }
    if (!wasDown && destroyed) {
      _rebuild = GameConfig.depotRebuildSeconds;
      _core.collisionType = CollisionType.inactive;
      parent?.add(Explosion(position: position.clone(), color: kind.color));
      return true;
    }
    return false;
  }

  @override
  void update(double dt) {
    _time += dt;
    if (_flash > 0) {
      _flash -= dt;
    }
    if (destroyed) {
      _rebuild -= dt;
      if (_rebuild <= 0) {
        setHp(GameConfig.depotHp);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    const r = GameConfig.depotRadius;
    final owner = GameConfig.teamColors[team];
    final pulse = 0.5 + 0.5 * sin(_time * (filling ? 8 : 2.5));
    canvas.drawCircle(
      c,
      r,
      Paint()..color = const Color(0xFF3E4A2A).withValues(alpha: 0.3),
    );
    if (destroyed) {
      _renderRuin(canvas, c);
      return;
    }
    canvas.drawCircle(
      c,
      r - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = filling ? 4 : 3
        ..color = kind.color.withValues(alpha: 0.35 + 0.35 * pulse),
    );
    if (team != 0) {
      canvas.drawCircle(
        c,
        r + 3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = owner.withValues(alpha: 0.8),
      );
    }
    switch (kind) {
      case DepotKind.fuel:
        _renderStation(canvas, c);
      case DepotKind.ammo:
        _renderDump(canvas, c);
    }
    if (hp < GameConfig.depotHp) {
      final bar = Rect.fromLTWH(c.dx - 20, c.dy + 26, 40, 4);
      canvas.drawRect(bar, Paint()..color = const Color(0xAA000000));
      canvas.drawRect(
        Rect.fromLTWH(
          bar.left,
          bar.top,
          bar.width * hp / GameConfig.depotHp,
          4,
        ),
        Paint()..color = kind.color,
      );
    }
  }

  Color _tint(Color base) =>
      _flash > 0 ? Color.lerp(base, const Color(0xFFFFFFFF), 0.5)! : base;

  /// A roof on two posts over a pair of pumps.
  void _renderStation(Canvas canvas, Offset c) {
    final roof = Rect.fromCenter(center: c, width: 40, height: 26);
    canvas.drawRect(
      roof.shift(const Offset(3, 3)),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawRect(roof, Paint()..color = _tint(const Color(0xFF6E7550)));
    canvas.drawRect(
      roof,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF2F3320),
    );
    final pump = Paint()..color = _tint(kind.color);
    for (final dx in [-9.0, 9.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c.translate(dx, 0), width: 8, height: 12),
          const Radius.circular(2),
        ),
        pump,
      );
    }
    // Drums along the side.
    for (var i = 0; i < 3; i++) {
      final p = c.translate(-14 + 14.0 * i, 24);
      canvas.drawCircle(p, 5, Paint()..color = const Color(0xFFB5541C));
      canvas.drawCircle(
        p,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF2B1608),
      );
    }
  }

  /// Crates in a ring of sandbags.
  void _renderDump(Canvas canvas, Offset c) {
    final sandbag = Paint()..color = const Color(0xFFB8A878);
    for (var i = 0; i < 10; i++) {
      final a = i * 2 * pi / 10;
      canvas.drawOval(
        Rect.fromCenter(
          center: c + Offset(cos(a), sin(a)) * 24,
          width: 12,
          height: 8,
        ),
        sandbag,
      );
    }
    final crate = Paint()..color = _tint(const Color(0xFF6B5A2E));
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF2E2614);
    for (final (dx, dy) in [(-7.0, -6.0), (7.0, -6.0), (0.0, 7.0)]) {
      final box = Rect.fromCenter(
        center: c.translate(dx, dy),
        width: 13,
        height: 11,
      );
      canvas.drawRect(box, crate);
      canvas.drawRect(box, edge);
    }
    canvas.drawCircle(c.translate(0, 7), 2.5, Paint()..color = kind.color);
  }

  /// Scorch marks and a ring that closes as the depot is rebuilt.
  void _renderRuin(Canvas canvas, Offset c) {
    canvas.drawCircle(c, 26, Paint()..color = const Color(0xCC1E1A14));
    final debris = Paint()..color = const Color(0xFF4A4034);
    for (var i = 0; i < 6; i++) {
      final a = i * 1.7 + index;
      canvas.drawRect(
        Rect.fromCenter(
          center: c + Offset(cos(a), sin(a)) * (8 + 3.0 * i),
          width: 7,
          height: 5,
        ),
        debris,
      );
    }
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: GameConfig.depotRadius - 4),
      -pi / 2,
      2 * pi * rebuildShare,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = kind.color.withValues(alpha: 0.5),
    );
  }
}

/// All depots of a round, placed from the seed once the buildings stand so
/// every client puts them in the same spots.
class SupplyField extends Component {
  SupplyField({required this.seed, required this.flag, required this.cover});

  final int seed;
  final bool flag;
  final CoverField cover;
  final depots = <SupplyDepot>[];

  SupplyDepot? depotAt(int index) =>
      index >= 0 && index < depots.length ? depots[index] : null;

  @override
  Future<void> onLoad() async {
    // The buildings come from the same seed; waiting for them keeps the
    // order the same on every client.
    await cover.loaded;
    final spots = layout(
      seed: seed,
      flag: flag,
      solids: [for (final o in cover.obstacles) o.toRect()],
    );
    for (final spot in spots) {
      final depot = SupplyDepot(
        index: depots.length,
        kind: spot.kind,
        team: spot.team,
        position: spot.position,
      );
      depots.add(depot);
      add(depot);
    }
  }

  /// Where the depots of a round stand. A free for all gets
  /// [GameConfig.depotCount] neutral ones on a ring, fuel and ammunition
  /// taking turns. Capture the flag gives each team a fuel station and an
  /// ammunition depot behind its base.
  static List<DepotSpot> layout({
    required int seed,
    required bool flag,
    List<Rect> solids = const [],
  }) {
    final random = Random(seed ^ 0xde90);
    bool clear(Vector2 at) => !solids.any(
      (o) =>
          o.inflate(GameConfig.depotRadius * 0.7).contains(Offset(at.x, at.y)),
    );

    /// [wanted] if it is free, else the nearest free spot of a few tries
    /// around it; [wanted] all the same when nothing is free.
    Vector2 near(Vector2 wanted, double spread) {
      if (clear(wanted)) {
        return wanted;
      }
      for (var attempt = 1; attempt <= 24; attempt++) {
        final a = random.nextDouble() * 2 * pi;
        final candidate =
            wanted + Vector2(cos(a), sin(a)) * (spread * attempt / 24);
        if (clear(candidate)) {
          return candidate;
        }
      }
      return wanted;
    }

    if (flag) {
      return [
        for (final team in const [1, 2])
          for (final kind in DepotKind.values)
            (
              kind: kind,
              team: team,
              position: near(
                FlagMatch.baseOf(team) +
                    Vector2(
                      (team == 1 ? -1 : 1) * GameConfig.flagDepotBehind,
                      (kind == DepotKind.fuel ? -1 : 1) *
                          GameConfig.flagDepotSide,
                    ),
                80,
              ),
            ),
      ];
    }
    final base = random.nextDouble() * 2 * pi;
    const count = GameConfig.depotCount;
    return [
      for (var i = 0; i < count; i++)
        () {
          final a =
              base + 2 * pi * i / count + (random.nextDouble() - 0.5) * 0.5;
          final distance =
              GameConfig.depotRingMin +
              random.nextDouble() *
                  (GameConfig.depotRingMax - GameConfig.depotRingMin);
          return (
            kind: i.isEven ? DepotKind.fuel : DepotKind.ammo,
            team: 0,
            position: near(Vector2(cos(a), sin(a)) * distance, 120),
          );
        }(),
    ];
  }
}
