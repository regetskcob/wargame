import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../game_config.dart';
import 'effects.dart';
import 'obstacle.dart';
import 'storm_zone.dart';

/// Infantry that walks little circles around its post. Every client derives
/// the same movement from the round seed and clock, so nobody has to send
/// positions: only the tank that drives over a soldier reports it.
class Soldier extends PositionComponent {
  Soldier({
    required this.index,
    required this.home,
    required this.phase,
    required this.reach,
    required this.speed,
    this.dropAt,
  }) : super(size: Vector2.all(16), anchor: Anchor.center, priority: 1);

  final int index;
  final Vector2 home;
  final double phase;
  final double reach;
  final double speed;

  /// Round clock second a paratrooper starts to fall, null for the infantry
  /// that stands there from the start.
  final double? dropAt;
  bool dead = false;
  double _gait = 0;
  late final CircleHitbox _hitbox;
  double _altitude = 0;
  double _drift = 0;
  bool _wasAirborne = false;

  /// Still hanging under the canopy: cannot be run over yet.
  bool get airborne {
    final drop = dropAt;
    final field = parent;
    return drop != null &&
        field is SoldierField &&
        field.clock < drop + GameConfig.paraFallSeconds;
  }

  Vector2 _at(double t) =>
      home +
      Vector2(cos(t * speed + phase), sin(t * speed * 0.8 + phase * 1.3)) *
          reach;

  @override
  void onLoad() {
    add(
      _hitbox = CircleHitbox(
        radius: 6,
        position: size / 2,
        anchor: Anchor.center,
        // Paratroopers only become solid once they touch the ground.
        collisionType: dropAt == null
            ? CollisionType.active
            : CollisionType.inactive,
      ),
    );
  }

  @override
  void update(double dt) {
    final field = parent;
    if (field is! SoldierField) {
      return;
    }
    final t = field.clock;
    final drop = dropAt;
    if (drop != null && t < drop + GameConfig.paraFallSeconds) {
      final lift =
          1 - ((t - drop) / GameConfig.paraFallSeconds).clamp(0.0, 1.0);
      _altitude = 340 * lift;
      _drift = 36 * lift;
      position.setValues(home.x + _drift, home.y - _altitude);
      angle = 0;
      _gait += dt * 2;
      if (!_wasAirborne) {
        _wasAirborne = true;
        priority = 30;
      }
      return;
    }
    if (_wasAirborne) {
      _wasAirborne = false;
      _altitude = 0;
      _drift = 0;
      priority = 1;
      field.parent?.add(
        puff(
          position: home.clone(),
          color: const Color(0xFFB59B6B),
          count: 6,
          lifespan: 0.7,
          speed: (8, 30),
          size: (3, 7),
          opacity: 0.5,
        ),
      );
    }
    // Also covers a client that joins after the wave has landed.
    if (_hitbox.collisionType != CollisionType.active) {
      _hitbox.collisionType = CollisionType.active;
    }
    final now = _at(t);
    final ahead = _at(t + 0.1);
    position.setFrom(now);
    final delta = ahead - now;
    if (delta.length2 > 0) {
      angle = atan2(delta.x, -delta.y);
    }
    _gait += dt * speed * 14;
  }

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(1.5 - _drift, 2 + _altitude),
        width: 12,
        height: 8,
      ),
      Paint()..color = const Color(0x44000000),
    );
    if (_wasAirborne) {
      // Canopy with its lines.
      final lines = Paint()
        ..strokeWidth = 0.8
        ..color = const Color(0xFFE6E2D3);
      canvas.drawLine(c, c.translate(-13, -19), lines);
      canvas.drawLine(c, c.translate(13, -19), lines);
      canvas.drawArc(
        Rect.fromCenter(center: c.translate(0, -19), width: 28, height: 22),
        pi,
        pi,
        true,
        Paint()..color = const Color(0xFFC8D6A0),
      );
      canvas.drawArc(
        Rect.fromCenter(center: c.translate(0, -19), width: 28, height: 22),
        pi,
        pi,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF4A5A2E),
      );
    }
    // Legs
    final swing = sin(_gait) * 2.2;
    final boot = Paint()..color = const Color(0xFF2B2B22);
    canvas.drawCircle(c.translate(-2.2, 3 + swing), 1.9, boot);
    canvas.drawCircle(c.translate(2.2, 3 - swing), 1.9, boot);
    // Rifle
    canvas.drawLine(
      c.translate(3, 2),
      c.translate(3, -9),
      Paint()
        ..strokeWidth = 1.6
        ..color = const Color(0xFF222222),
    );
    // Shoulders and backpack
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 12, height: 6.5),
      Paint()..color = const Color(0xFF6B7F3A),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, 2.4), width: 7, height: 4.5),
      Paint()..color = const Color(0xFF4A5A2E),
    );
    // Arms and helmet
    final skin = Paint()..color = const Color(0xFFC9A27E);
    canvas.drawCircle(c.translate(-4.6, -1.2 + swing * 0.4), 1.4, skin);
    canvas.drawCircle(c.translate(3.4, -3.5), 1.4, skin);
    canvas.drawCircle(c, 3.4, Paint()..color = const Color(0xFF3E4A28));
    canvas.drawCircle(
      c.translate(-0.7, -0.7),
      1.2,
      Paint()..color = const Color(0x33FFFFFF),
    );
  }
}

/// A stain left where a soldier was run over. It dries to a dark brown.
class BloodSplat extends PositionComponent {
  BloodSplat({required super.position, required this.seed})
    : super(priority: -1);

  final int seed;
  double _age = 0;
  late final List<(Offset, double)> _blobs = () {
    final random = Random(seed * 7919 + 13);
    return [
      for (var i = 0; i < 9; i++)
        (
          Offset(
            (random.nextDouble() * 2 - 1) * 13,
            (random.nextDouble() * 2 - 1) * 13,
          ),
          2.5 + random.nextDouble() * 6,
        ),
    ];
  }();

  @override
  void update(double dt) {
    _age += dt;
  }

  @override
  void render(Canvas canvas) {
    final dry = (_age / 25).clamp(0.0, 1.0);
    final color = Color.lerp(
      const Color(0xFF8E1010),
      const Color(0xFF4A1C16),
      dry,
    )!;
    final paint = Paint()..color = color.withValues(alpha: 0.9 - 0.2 * dry);
    for (final (offset, radius) in _blobs) {
      canvas.drawOval(
        Rect.fromCenter(
          center: offset,
          width: radius * 2,
          height: radius * 1.6,
        ),
        paint,
      );
    }
  }
}

/// All the soldiers of a round, placed in squads away from the start ring
/// and from buildings.
class SoldierField extends Component {
  SoldierField({required this.seed, required this.startedAt, this.onWave})
    : super(priority: -12);

  /// Called when a wave of paratroopers starts to fall.
  final void Function()? onWave;

  final int seed;
  final int startedAt;
  final soldiers = <Soldier>[];
  bool _built = false;
  bool get built => _built;
  final _pending = <Soldier>[];
  final _announced = <double>{};

  /// Seconds since the round clock started.
  double get clock =>
      (DateTime.now().millisecondsSinceEpoch - startedAt) / 1000;

  Soldier? soldierAt(int index) =>
      index >= 0 && index < soldiers.length ? soldiers[index] : null;

  void addSplat(Vector2 at, int index) {
    add(BloodSplat(position: at.clone(), seed: index));
    final splats = children.whereType<BloodSplat>().toList();
    if (splats.length > 60) {
      splats.first.removeFromParent();
    }
  }

  /// Built on the first frame, once the terrain exists and can be avoided.
  void _build() {
    _built = true;
    final random = Random(seed ^ 0x5017);
    final solids = parent?.descendants().whereType<Obstacle>().toList() ?? [];
    for (var squad = 0; squad < GameConfig.soldierSquads; squad++) {
      Vector2? centre;
      for (var attempt = 0; attempt < 40 && centre == null; attempt++) {
        final distance = 180 + random.nextDouble() * 600;
        if ((distance - GameConfig.spawnRadius).abs() < 90) {
          continue;
        }
        final a = random.nextDouble() * 2 * pi;
        final candidate = Vector2(cos(a), sin(a))..scale(distance);
        final blocked = solids.any(
          (o) =>
              o.toRect().inflate(60).contains(Offset(candidate.x, candidate.y)),
        );
        if (!blocked) {
          centre = candidate;
        }
      }
      if (centre == null) {
        continue;
      }
      for (var i = 0; i < GameConfig.soldiersPerSquad; i++) {
        final a = random.nextDouble() * 2 * pi;
        final soldier = Soldier(
          index: soldiers.length,
          home:
              centre +
              Vector2(cos(a), sin(a)) * (10 + random.nextDouble() * 40),
          phase: random.nextDouble() * 2 * pi,
          reach: 8 + random.nextDouble() * 22,
          speed: 0.5 + random.nextDouble() * 0.6,
        );
        soldiers.add(soldier);
        add(soldier);
      }
    }
    _planParatroopers(solids);
  }

  /// Waves of paratroopers: when and where they land follows from the seed.
  void _planParatroopers(List<Obstacle> solids) {
    final random = Random(seed ^ 0xfa11);
    for (var wave = 0; wave < GameConfig.paraWaves; wave++) {
      final dropAt = GameConfig.paraFirstWave + wave * GameConfig.paraWaveEvery;
      final safe = StormZone.radiusAt(
        startedAt,
        startedAt + ((dropAt + GameConfig.paraFallSeconds) * 1000).round(),
      );
      Vector2? centre;
      for (var attempt = 0; attempt < 40 && centre == null; attempt++) {
        final distance = sqrt(random.nextDouble()) * (safe - 90).clamp(40, 650);
        final a = random.nextDouble() * 2 * pi;
        final candidate = Vector2(cos(a), sin(a))..scale(distance);
        final blocked = solids.any(
          (o) =>
              o.toRect().inflate(40).contains(Offset(candidate.x, candidate.y)),
        );
        if (!blocked) {
          centre = candidate;
        }
      }
      for (var i = 0; i < GameConfig.paraPerWave; i++) {
        final a = random.nextDouble() * 2 * pi;
        final home =
            (centre ?? Vector2.zero()) +
            Vector2(cos(a), sin(a)) * (10 + random.nextDouble() * 40);
        final soldier = Soldier(
          index: soldiers.length,
          home: home,
          phase: random.nextDouble() * 2 * pi,
          reach: 8 + random.nextDouble() * 22,
          speed: 0.5 + random.nextDouble() * 0.6,
          dropAt: dropAt,
        );
        soldiers.add(soldier);
        _pending.add(soldier);
      }
    }
  }

  @override
  void update(double dt) {
    if (!_built && isMounted) {
      _build();
    }
    if (_pending.isNotEmpty) {
      final now = clock;
      for (final soldier in _pending.where((s) => now >= s.dropAt!).toList()) {
        _pending.remove(soldier);
        if (soldier.dead) {
          continue;
        }
        add(soldier);
        if (_announced.add(soldier.dropAt!)) {
          onWave?.call();
        }
      }
    }
  }
}
