import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';

import '../game_config.dart';
import '../game_phase.dart';
import '../tank_game.dart';
import 'defense_map.dart';
import '../../l10n/l10n.dart';

/// What a player can put down in a defense round. Each gun has its job: the
/// cannon for tanks, flak for helicopters, jets and drones, the mortar for
/// tanks and soldiers bunched up on the road and, later on, the howitzer for
/// everything far out. The trench holds riflemen and a machine gun against
/// soldiers on foot and covers a tank that stands in it; on the road it
/// lies across it and tanks crawl over it. The heavier pieces only come up
/// after a few waves.
enum TowerKind {
  cannon(
    'KANONE',
    'CANNON',
    cost: 100,
    range: 420,
    cooldown: 0.45,
    damage: 18,
    shotSpeed: 560,
  ),
  flak(
    'FLAK',
    'FLAK',
    cost: 120,
    range: 600,
    cooldown: 0.16,
    damage: 6,
    shotSpeed: 720,
    antiAir: true,
    groundFactor: 0.3,
    burst: 30,
    traverse: 10,
  ),
  mortar(
    'MÖRSER',
    'MORTAR',
    cost: 150,
    range: 620,
    cooldown: 2.4,
    damage: 0,
    shotSpeed: 0,
    minRange: 130,
  ),
  howitzer(
    'HAUBITZE',
    'HOWITZER',
    cost: 220,
    range: 1050,
    cooldown: 4.2,
    damage: 0,
    shotSpeed: 0,
    minRange: 240,
    blast: 2.2,
    fromWave: 4,
  ),
  // Its rifles and machine gun take turns: [cooldown] is the gap between
  // two shots of the whole trench, as long as all its men are there.
  trench(
    'GRABEN',
    'TRENCH',
    cost: 60,
    range: 260,
    cooldown: 0.35,
    damage: 3,
    shotSpeed: GameConfig.rifleSpeed,
    traverse: 20,
    fromWave: 2,
  ),
  rockets(
    'RAKETEN',
    'ROCKETS',
    cost: 260,
    range: 640,
    cooldown: 1.4,
    damage: 42,
    shotSpeed: 640,
    antiAir: true,
    extension: true,
  );

  const TowerKind(
    this._labelDe,
    this._labelEn, {
    required this.cost,
    required this.range,
    required this.cooldown,
    required this.damage,
    required this.shotSpeed,
    this.antiAir = false,
    this.groundFactor = 1,
    this.burst = 0,
    this.traverse = 6,
    this.minRange = 0,
    this.blast = 1,
    this.fromWave = 0,
    this.extension = false,
  });

  final String _labelDe;
  final String _labelEn;
  String get label => tr(_labelDe, _labelEn);
  final int cost;
  final double range;
  final double cooldown;

  /// Damage of one shell. The mortar's comes from its blast instead.
  final double damage;
  final double shotSpeed;

  /// Aims at aircraft and drones first, and hits them hard.
  final bool antiAir;

  /// Share of [damage] that reaches tanks, guns and soldiers. Flak is built
  /// for the sky: on the ground its light shells barely scratch, or a row
  /// of flak would hold the road as well as the cannon does.
  final double groundFactor;

  /// Flak shells carry a proximity fuse: they burst this close to an
  /// aircraft or drone instead of having to strike it. Without it a jet at
  /// full speed slipped through even three flak guns around the base.
  final double burst;

  /// How fast the turret swings round, in radians a second. The light flak
  /// mount follows a jet that races past, the heavy guns are slower.
  final double traverse;

  /// What one shell of a gun at [level] does to aircraft and drones.
  double airDamageAt(int level) =>
      damage * damageFactor(level) * GameConfig.antiAirFactor;

  /// What one shell of a gun at [level] does to everything on the ground.
  double groundDamageAt(int level) =>
      damage * damageFactor(level) * groundFactor;

  /// The mortar and the howitzer cannot fire at what is right next to them.
  final double minRange;

  /// How hard a lobbed shell hits, against the mortar's.
  final double blast;

  /// Wave from which it can be built, 0 from the start.
  final int fromWave;

  /// Only to be had once the defenders extend past the last regular wave.
  final bool extension;

  /// Fires shells in a high arc that burst where they land.
  bool get lobs => this == mortar || this == howitzer;

  bool get isGun => this != trench;
  bool get upgradable => isGun;

  bool unlockedIn(int wave, {bool extended = false}) =>
      extension ? extended : wave >= fromWave;

  /// What keeps it locked, null when it can be built.
  String? lockedIn(int wave, {bool extended = false}) =>
      unlockedIn(wave, extended: extended)
      ? null
      : extension
      ? tr('in der Verlängerung', 'in the extension')
      : tr('ab Welle $fromWave', 'from wave $fromWave');

  /// Three steps, two more in the extension.
  static const maxLevel = 5;
  static int levelLimit({required bool extended}) => extended ? 5 : 3;

  /// What the step from [level] to the next costs.
  int upgradeCost(int level) => (cost * 0.75 * level).round();

  double damageFactor(int level) => 1 + 0.35 * (level - 1);
  double rangeAt(int level) => range * (1 + 0.12 * (level - 1));
  double cooldownAt(int level) => cooldown * (1 - 0.15 * (level - 1));

  /// How much fire it takes before it is destroyed, more with every level.
  double maxHpAt(int level) =>
      switch (this) {
        TowerKind.cannon => 240.0,
        TowerKind.flak => 200.0,
        TowerKind.mortar => 200.0,
        TowerKind.howitzer => 300.0,
        TowerKind.trench => 360.0,
        TowerKind.rockets => 260.0,
      } *
      (1 + 0.3 * (level - 1));

  String get hint => switch (this) {
    TowerKind.cannon => tr('gegen Panzer', 'against tanks'),
    TowerKind.flak => tr('gegen Luftziele', 'against air targets'),
    TowerKind.mortar => tr('Flächenfeuer', 'area fire'),
    TowerKind.howitzer => tr(
      'Flächenfeuer auf große Entfernung',
      'area fire at long range',
    ),
    TowerKind.trench => tr(
      'Schützen und MG gegen Infanterie, halber Schaden für den Panzer darin',
      'riflemen and a machine gun against infantry, half damage for the tank '
          'inside',
    ),
    TowerKind.rockets => tr(
      'gegen Panzer und Luftziele',
      'against tanks and air targets',
    ),
  };
}

/// A gun emplacement a player put down. It never moves. Enemy shells, bombs
/// and blasts wear it down until it is destroyed; the player who runs the
/// enemies keeps its hit points. Only the client of its builder aims and
/// fires it, everybody else sees the shots as they come in.
///
/// The faint areas the guns reach, under the guns. Each gun filled its own
/// circle before, hundreds of points across: a late defense wave with 17
/// guns coloured much of the screen 17 times over, which cost an older
/// iPad 3 ms a frame. One shape per builder's colour covers every point
/// once, however many guns overlap there.
class TowerRanges extends Component with HasGameRef<TankGame> {
  TowerRanges() : super(priority: 7);

  final _areas = <Color, Path>{};

  @override
  void render(Canvas canvas) {
    for (final path in _areas.values) {
      path.reset();
    }
    for (final tower in gameRef.towers.values) {
      if (tower.isHq || !tower.isMounted) {
        continue;
      }
      (_areas[tower.color] ??= Path()).addOval(
        Rect.fromCircle(center: tower.position.toOffset(), radius: tower.range),
      );
    }
    final paint = Paint();
    for (final MapEntry(key: color, value: path) in _areas.entries) {
      canvas.drawPath(path, paint..color = color.withValues(alpha: 0.05));
    }
  }
}

/// The guns of the base itself ([isHq]) come with the base as it grows. They
/// stand on it, cannot be hit and cannot be bought or upgraded.
class Tower extends PositionComponent with HasGameRef<TankGame> {
  Tower({
    required this.ownerId,
    required this.index,
    required this.color,
    required super.position,
    this.kind = TowerKind.cannon,
    this.level = 1,
  }) : super(
         size: Vector2.all(72),
         anchor: Anchor.center,
         // A trench lies in the ground, under the tank that sits in it.
         priority: kind == TowerKind.trench ? -5 : 8,
       );

  final String ownerId;
  final int index;
  final Color color;
  final TowerKind kind;
  int level;

  String get id => '$ownerId#$index';

  /// Index from which the guns belong to the base, not to a player.
  static const hqIndex = 1000;

  bool get isHq => index >= hqIndex;

  late double hp = kind.maxHpAt(level);
  double get maxHp => kind.maxHpAt(level);
  double _flash = 0;

  /// Shows a hit.
  void hit() => _flash = 0.12;

  /// Who last hit it as this client saw it: whoever destroys a gun of the
  /// enemy earns the bounty on their own screen.
  String? lastHitBy;

  /// A gun the enemy dug in beside the road, see [GameConfig.enemyGunsIn].
  bool get isEnemy => gameRef.round?.isEnemy(ownerId) ?? false;

  double get range => kind.rangeAt(level);

  /// The men in a trench, fewer as it takes fire, and the one that fires
  /// next.
  static const trenchCrew = 4;
  int _shooter = 0;

  /// Seconds until a trench that stopped firing looks out again.
  double _quiet = 0;

  /// Along the trench: across the road when it lies on the road, else along
  /// the road it faces. Every client works it out from the same spot on
  /// the same map.
  late final Vector2 trenchAxis = () {
    final map = gameRef.defenseMap;
    if (map == null) {
      return Vector2(1, 0);
    }
    final (_, dir) = map.nearestOnRoad(position);
    return onRoad ? Vector2(-dir.y, dir.x) : dir;
  }();

  /// A trench dug on the road reaches from one edge of it to the other.
  late final bool onRoad =
      kind == TowerKind.trench &&
      (gameRef.defenseMap?.distanceToRoad(position) ?? double.infinity) <
          DefenseMap.roadHalfWidth;

  /// Where the men of a trench look while nothing is in reach: on the road
  /// up it, where the enemy comes from, beside it over the road. Without
  /// it they all faced up the screen and so often away from the attack.
  late final double restAngle = () {
    final map = gameRef.defenseMap;
    if (map == null) {
      return 0.0;
    }
    final (point, dir) = map.nearestOnRoad(position);
    final look = onRoad || point.distanceTo(position) < 1
        ? -dir
        : point - position;
    return atan2(look.x, -look.y);
  }();

  /// Length of a trench along [trenchAxis].
  double get trenchLength =>
      onRoad ? DefenseMap.roadHalfWidth * 2 + 20 : GameConfig.trenchLength;

  /// Men still in the trench: one goes with every quarter of its hit points.
  int get crew => (trenchCrew * hp / maxHp).ceil().clamp(0, trenchCrew);

  /// Where the man [i] of the trench stands, in the world.
  Vector2 crewAt(int i) =>
      position + trenchAxis * (trenchLength * ((i + 0.5) / trenchCrew - 0.5));

  /// Whether [at] lies in the trench, within [margin] of its edge.
  bool covers(Vector2 at, {double margin = 0}) {
    final offset = at - position;
    final along = offset.dot(trenchAxis).abs();
    final across = (offset.x * trenchAxis.y - offset.y * trenchAxis.x).abs();
    return along <= trenchLength / 2 + margin &&
        across <= GameConfig.trenchHalfWidth + margin;
  }

  /// Where the next shot leaves and where it flies: from the gun's muzzle
  /// where the gun points, or from the rifle of the man in the trench whose
  /// turn it is, straight at what he aims at. Aiming from the middle of a
  /// trench across the road sent the shots of the men at its ends past
  /// soldiers close by.
  (Vector2, Vector2) nextShot() {
    final pointing = Vector2(sin(turretAngle), -cos(turretAngle));
    if (kind != TowerKind.trench) {
      return (position + pointing * 44, pointing);
    }
    final men = max(1, crew);
    _shooter = (_shooter + 1) % men;
    final from = crewAt(_shooter);
    final aim = _aim;
    final direction = aim == null || aim.distanceTo(from) < 1
        ? pointing
        : (aim - from).normalized();
    return (from + direction * 8, direction);
  }

  /// What the men of a trench aim at, in the world. On the other clients a
  /// point along the last shot.
  Vector2? _aim;

  /// Where the man [i] of a trench points his rifle.
  double _aimOf(int i) {
    final aim = _aim;
    if (aim == null || _quiet == 0) {
      return turretAngle;
    }
    final from = crewAt(i);
    return atan2(aim.x - from.x, -(aim.y - from.y));
  }

  double turretAngle = 0;
  double _cooldown = 0;
  double _recoil = 0;
  double _think = 0;
  double _upgraded = 0;
  PositionComponent? _target;

  bool get _mine => ownerId == gameRef.myId;

  /// This client aims and fires it: its builder, and for the enemy's guns
  /// the player who runs the waves.
  bool get _runs =>
      _mine || (isEnemy && gameRef.round?.botHost == gameRef.myId);

  /// A shot went off in [direction]. For a trench of another client [from]
  /// tells which of the men fired, so the flash shows at his rifle.
  void fired(Vector2 direction, {Vector2? from}) {
    turretAngle = atan2(direction.x, -direction.y);
    _recoil = 1;
    _quiet = 1.5;
    if (from != null && kind == TowerKind.trench) {
      _aim = from + direction * 150;
      var best = double.infinity;
      for (var i = 0; i < trenchCrew; i++) {
        final distance = crewAt(i).distanceTo(from);
        if (distance < best) {
          best = distance;
          _shooter = i;
        }
      }
    }
  }

  void upgradeTo(int value) {
    if (value > level) {
      final before = maxHp;
      level = value;
      hp += maxHp - before;
      _upgraded = 1;
    }
  }

  /// Turns the aim towards [wanted] at the kind's pace.
  void _turnTo(double wanted, double dt) {
    final diff = (wanted - turretAngle).toNormalizedAngle();
    final turn = kind.traverse * dt;
    turretAngle += diff.clamp(-turn, turn);
  }

  @override
  void onLoad() {
    if (kind == TowerKind.trench) {
      turretAngle = restAngle;
    }
    // A manned trench is hit along its length; without that tank shells
    // flew through it and only blasts wore it down.
    if (kind == TowerKind.trench) {
      add(
        RectangleHitbox(
          position: size / 2,
          size: Vector2(trenchLength, GameConfig.trenchHalfWidth * 2),
          anchor: Anchor.center,
          angle: atan2(trenchAxis.y, trenchAxis.x),
          collisionType: CollisionType.passive,
        ),
      );
    }
    // Shells only stop at what stands up from the ground.
    if (kind.isGun && !isHq) {
      add(
        CircleHitbox(
          radius: 26,
          position: size / 2,
          anchor: Anchor.center,
          collisionType: CollisionType.passive,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    _recoil = max(0, _recoil - dt * 6);
    _upgraded = max(0, _upgraded - dt);
    _flash = max(0, _flash - dt);
    _quiet = max(0, _quiet - dt);
    // Every client: a trench that has not fired for a moment looks out
    // where the enemy comes from again.
    if (kind == TowerKind.trench && _quiet == 0) {
      _turnTo(restAngle, dt);
    }
    if (!_runs || (kind == TowerKind.trench && crew == 0)) {
      return;
    }
    final phase = gameRef.phase.value;
    if (phase != GamePhase.playing && phase != GamePhase.spectating) {
      return;
    }
    _cooldown -= dt;
    _think -= dt;
    if (_think <= 0) {
      _think = 0.2;
      _target = gameRef.towerTarget(this);
    }
    _fireRocket(dt);
    final target = _target;
    if (target == null || !target.isMounted) {
      return;
    }
    final aim = kind.lobs ? target.position.clone() : _lead(target);
    _aim = aim;
    final wanted = atan2(aim.x - position.x, -(aim.y - position.y));
    final diff = (wanted - turretAngle).toNormalizedAngle();
    final turn = kind.traverse * dt;
    turretAngle += diff.clamp(-turn, turn);
    // The men of a trench each aim for themselves.
    if ((kind == TowerKind.trench || diff.abs() < 0.08) && _cooldown <= 0) {
      _cooldown =
          kind.cooldownAt(level) *
          (isEnemy ? GameConfig.enemyGunCooldown : 1) *
          // A trench fires slower with every man it lost.
          (kind == TowerKind.trench ? trenchCrew / max(1, crew) : 1);
      if (kind.lobs) {
        gameRef.fireMortarTower(this, aim);
      } else {
        gameRef.fireTower(this);
      }
    }
  }

  /// From [GameConfig.trenchRocketFromWave] on the first man of a trench,
  /// the last to fall, carries an anti-tank rocket launcher.
  bool get antiTank =>
      kind == TowerKind.trench &&
      (gameRef.defense.value?.wave ?? 0) >= GameConfig.trenchRocketFromWave;

  double _rocketCooldown = 0;

  /// The rocket man fires at the nearest enemy tank in his reach, leading
  /// it as the rifles do.
  void _fireRocket(double dt) {
    if (!antiTank) {
      return;
    }
    _rocketCooldown -= dt;
    if (_rocketCooldown > 0) {
      return;
    }
    final own = gameRef.round?.teamOf(ownerId) ?? 1;
    final from = crewAt(0);
    final tank = gameRef.nearestHostile(from, GameConfig.rocketRange, own);
    if (tank == null) {
      _rocketCooldown = 0.3;
      return;
    }
    _rocketCooldown = GameConfig.trenchRocketCooldown;
    var aim = tank.position.clone();
    final velocity = gameRef.velocityOfTarget(tank);
    for (var i = 0; i < 3; i++) {
      aim =
          tank.position +
          velocity * (aim.distanceTo(from) / GameConfig.rocketSpeed);
    }
    _aim = aim;
    gameRef.fireTrenchRocket(this, (aim - from).normalized());
  }

  /// Where to aim so a shell meets [target]: the flight time to where it
  /// will be, worked out a few times over, since a jet moves far in the
  /// time a shell takes to reach where it was.
  Vector2 _lead(PositionComponent target) {
    final velocity = gameRef.velocityOfTarget(target);
    var aim = target.position.clone();
    for (var i = 0; i < 3; i++) {
      final flight = aim.distanceTo(position) / kind.shotSpeed;
      aim = target.position + velocity * flight;
    }
    return aim;
  }

  @override
  void render(Canvas canvas) {
    if (kind == TowerKind.trench) {
      _renderTrench(canvas);
      _renderHp(canvas);
      return;
    }
    final c = Offset(size.x / 2, size.y / 2);
    if (isHq) {
      _renderTurret(canvas, c);
      return;
    }
    // Faint ring of how far the gun reaches, so the field shows at a glance
    // which stretch of the road is covered. The faint area inside it is
    // drawn for all guns at once by [TowerRanges].
    canvas.drawCircle(
      c,
      range,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: _mine ? 0.35 : 0.2),
    );
    // Sandbagged pit with a rim in the colour of the builder, bright enough
    // to stand out from the ground from far up.
    canvas.drawCircle(
      c + const Offset(3, 4),
      30,
      Paint()..color = const Color(0x66000000),
    );
    canvas.drawCircle(c, 30, Paint()..color = const Color(0xFFB59B6B));
    canvas.drawCircle(
      c,
      30,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = color,
    );
    canvas.drawCircle(
      c,
      33,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF101010),
    );
    final concrete = switch (kind) {
      TowerKind.cannon => const Color(0xFF55574F),
      TowerKind.flak => const Color(0xFF4E5E6C),
      TowerKind.mortar => const Color(0xFF6B5E48),
      TowerKind.howitzer => const Color(0xFF4A4F3A),
      TowerKind.trench => const Color(0xFF3B2E20),
      TowerKind.rockets => const Color(0xFF5A4A44),
    };
    final pad = Rect.fromCenter(center: c, width: 34, height: 34);
    if (kind.lobs) {
      canvas.drawCircle(c, 18, Paint()..color = concrete);
    } else {
      canvas.drawRect(pad, Paint()..color = concrete);
      canvas.drawRect(
        pad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF1E1E1C),
      );
    }
    _renderTurret(canvas, c);
    // One chevron per level above the first, under the pit.
    final pip = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Color.lerp(
        const Color(0xFFFFD54F),
        const Color(0xFFFFFFFF),
        _upgraded,
      )!;
    for (var i = 1; i < level; i++) {
      final y = c.dy + 36 + i * 7.0;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - 10, y)
          ..lineTo(c.dx, y - 6)
          ..lineTo(c.dx + 10, y),
        pip,
      );
    }
    _renderHp(canvas);
  }

  void _renderTurret(Canvas canvas, Offset c) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(turretAngle);
    final barrel = Paint()
      ..color = const Color(0xFF1E1E1C)
      ..strokeCap = StrokeCap.round;
    final recoil = 6 * _recoil;
    switch (kind) {
      case TowerKind.cannon:
        for (final x in const [-5.0, 5.0]) {
          canvas.drawLine(
            Offset(x, recoil),
            Offset(x, -40 + recoil),
            barrel..strokeWidth = 7,
          );
        }
      case TowerKind.flak:
        for (final x in const [-9.0, -3.0, 3.0, 9.0]) {
          canvas.drawLine(
            Offset(x, recoil / 2),
            Offset(x, -40 + recoil / 2),
            barrel..strokeWidth = 4,
          );
        }
      case TowerKind.mortar:
        canvas.drawLine(
          Offset(0, recoil / 2),
          Offset(0, -20 + recoil / 2),
          barrel..strokeWidth = 16,
        );
      case TowerKind.howitzer:
        // Split trail behind, a long barrel with a muzzle brake in front.
        for (final x in const [-12.0, 12.0]) {
          canvas.drawLine(
            Offset(x * 0.5, 6),
            Offset(x, 30),
            barrel..strokeWidth = 5,
          );
        }
        canvas.drawLine(
          Offset(0, 4 + recoil),
          Offset(0, -50 + recoil),
          barrel..strokeWidth = 8,
        );
        canvas.drawLine(
          Offset(-6, -48 + recoil),
          Offset(6, -48 + recoil),
          barrel..strokeWidth = 5,
        );
      case TowerKind.rockets:
        // A box of four tubes, the rockets' tips showing.
        final box = Rect.fromLTWH(-13, -34 + recoil / 2, 26, 30);
        canvas.drawRect(box, barrel);
        for (final x in const [-6.5, 6.5]) {
          for (final y in const [-28.0, -16.0]) {
            canvas.drawCircle(
              Offset(x, y + recoil / 2),
              4,
              Paint()..color = const Color(0xFFD1492E),
            );
          }
        }
      case TowerKind.trench:
        break;
    }
    if (_recoil > 0.6 && !kind.lobs) {
      canvas.drawCircle(
        const Offset(0, -46),
        9,
        Paint()..color = const Color(0xCCFFD27A),
      );
    }
    canvas.drawCircle(Offset.zero, 15, Paint()..color = color);
    canvas.drawCircle(
      Offset.zero,
      15,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF101010),
    );
    canvas.restore();
  }

  /// A bar under it once it took fire, white for a moment on every hit.
  void _renderHp(Canvas canvas) {
    if (isHq || hp >= maxHp) {
      return;
    }
    final ratio = (hp / maxHp).clamp(0.0, 1.0);
    final bar = Rect.fromLTWH(size.x / 2 - 24, -6, 48, 5);
    canvas.drawRect(bar, Paint()..color = const Color(0xAA000000));
    canvas.drawRect(
      Rect.fromLTWH(bar.left, bar.top, bar.width * ratio, bar.height),
      Paint()
        ..color = _flash > 0
            ? const Color(0xFFFFFFFF)
            : ratio > 0.35
            ? const Color(0xFF9CCC65)
            : const Color(0xFFD1492E),
    );
  }

  static final _earth = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFFB59B6B);
  static final _pit = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF3B2E20);
  static final _helmet = Paint()..color = const Color(0xFF3E4A28);
  // Lighter than the soldiers on the field, or they sank into the dark pit.
  static final _shoulders = Paint()..color = const Color(0xFF8A9F55);
  static final _gun = Paint()
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF1E1E1C);
  static final _flashPaint = Paint()..color = const Color(0xCCFFD27A);
  static final _rocketTip = Paint()..color = const Color(0xFFD1492E);

  /// A zigzag of dug earth with sandbags on the rim, across the road or
  /// along it, and the men in it with their rifles and the machine gun,
  /// all aiming where the trench fires. A band in the colour of who dug it.
  void _renderTrench(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    final half = trenchLength / 2;
    final axis = atan2(trenchAxis.y, trenchAxis.x);
    canvas.drawCircle(
      c,
      range,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: _mine ? 0.25 : 0.15),
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(axis);
    final steps = (trenchLength / 12).round();
    final zigzag = Path()..moveTo(-half, 5);
    for (var i = 1; i <= steps; i++) {
      zigzag.lineTo(-half + i * trenchLength / steps, i.isEven ? 5 : -5);
    }
    canvas.drawPath(zigzag, _earth..strokeWidth = 24);
    canvas.drawPath(zigzag, _pit..strokeWidth = 13);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: trenchLength + 6,
          height: 30,
        ),
        const Radius.circular(10),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color,
    );
    canvas.restore();
    // The men, upright in the world so their rifles point at the target.
    final men = crew;
    for (var i = 0; i < men; i++) {
      final at = crewAt(i) - position;
      final man = c + Offset(at.x, at.y);
      canvas.save();
      canvas.translate(man.dx, man.dy);
      canvas.rotate(_aimOf(i));
      final machineGun = i == 1;
      final recoil = i == _shooter ? 3 * _recoil : 0.0;
      if (i == 0 && antiTank) {
        // The launch tube over the shoulder, its rocket's tip showing.
        canvas.drawLine(
          const Offset(4, 6),
          const Offset(4, -13),
          _gun..strokeWidth = 3.5,
        );
        canvas.drawCircle(const Offset(4, -13), 2.2, _rocketTip);
      }
      canvas.drawLine(
        Offset(machineGun ? 0 : 3, recoil),
        Offset(machineGun ? 0 : 3, (machineGun ? -16 : -11) + recoil),
        _gun..strokeWidth = machineGun ? 3 : 1.6,
      );
      if (machineGun) {
        // The bipod at the front.
        canvas.drawLine(const Offset(-3, -12), const Offset(3, -12), _gun);
      }
      if (i == _shooter && _recoil > 0.5) {
        canvas.drawCircle(
          Offset(machineGun ? 0 : 3, machineGun ? -18 : -13),
          machineGun ? 3.5 : 2.5,
          _flashPaint,
        );
      }
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 13, height: 7),
        _shoulders,
      );
      canvas.drawCircle(Offset.zero, 4, _helmet);
      canvas.drawCircle(
        Offset.zero,
        4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = color,
      );
      canvas.restore();
    }
  }
}
