import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';

import '../game_config.dart';
import '../game_phase.dart';
import '../tank_game.dart';
import '../../l10n/l10n.dart';

/// What a player can put down in a defense round. Each gun has its job: the
/// cannon for tanks, flak for helicopters, jets and drones, the mortar for
/// tanks and soldiers bunched up on the road and, later on, the howitzer for
/// everything far out. The trench fires nothing, it covers a tank that
/// stands in it. The heavier pieces only come up after a few waves.
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
    range: 480,
    cooldown: 0.16,
    damage: 6,
    shotSpeed: 720,
    antiAir: true,
    groundFactor: 0.3,
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
  trench(
    'GRABEN',
    'TRENCH',
    cost: 60,
    range: 0,
    cooldown: 0,
    damage: 0,
    shotSpeed: 0,
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
      'halber Schaden für den Panzer darin',
      'half damage for the tank inside',
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

  void fired(Vector2 direction) {
    turretAngle = atan2(direction.x, -direction.y);
    _recoil = 1;
  }

  void upgradeTo(int value) {
    if (value > level) {
      final before = maxHp;
      level = value;
      hp += maxHp - before;
      _upgraded = 1;
    }
  }

  @override
  void onLoad() {
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
    if (!_runs || !kind.isGun) {
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
    final target = _target;
    if (target == null || !target.isMounted) {
      return;
    }
    final aim = kind.lobs
        ? target.position.clone()
        : target.position +
              gameRef.velocityOfTarget(target) *
                  (target.position.distanceTo(position) / kind.shotSpeed);
    final wanted = atan2(aim.x - position.x, -(aim.y - position.y));
    final diff = (wanted - turretAngle).toNormalizedAngle();
    turretAngle += diff.clamp(-6 * dt, 6 * dt);
    if (diff.abs() < 0.08 && _cooldown <= 0) {
      _cooldown =
          kind.cooldownAt(level) * (isEnemy ? GameConfig.enemyGunCooldown : 1);
      if (kind.lobs) {
        gameRef.fireMortarTower(this, aim);
      } else {
        gameRef.fireTower(this);
      }
    }
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
    // which stretch of the road is covered.
    canvas.drawCircle(c, range, Paint()..color = color.withValues(alpha: 0.05));
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

  /// A zigzag of dug earth with sandbags on the rim, open towards the road,
  /// in the colour of who dug it.
  void _renderTrench(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(c, 34, Paint()..color = color.withValues(alpha: 0.12));
    final zigzag = Path()..moveTo(c.dx - 30, c.dy + 6);
    for (var i = 1; i <= 6; i++) {
      zigzag.lineTo(c.dx - 30 + i * 10, c.dy + (i.isEven ? 6 : -6));
    }
    canvas.drawPath(
      zigzag,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFB59B6B),
    );
    canvas.drawPath(
      zigzag,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF3B2E20),
    );
    canvas.drawCircle(
      c,
      34,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color,
    );
  }
}
