import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';

import '../../game_config.dart';
import '../game_phase.dart';
import '../space_game.dart';

/// The guns a player can put down in a defense round. Each has its job: the
/// cannon for tanks, flak for helicopters, jets and drones, the mortar for
/// tanks and soldiers bunched up on the road.
enum TowerKind {
  cannon(
    'KANONE',
    cost: 100,
    range: 420,
    cooldown: 0.45,
    damage: 18,
    shotSpeed: 560,
  ),
  flak(
    'FLAK',
    cost: 120,
    range: 480,
    cooldown: 0.16,
    damage: 6,
    shotSpeed: 720,
    antiAir: true,
  ),
  mortar(
    'MÖRSER',
    cost: 150,
    range: 620,
    cooldown: 2.4,
    damage: 0,
    shotSpeed: 0,
    minRange: 130,
  );

  const TowerKind(
    this.label, {
    required this.cost,
    required this.range,
    required this.cooldown,
    required this.damage,
    required this.shotSpeed,
    this.antiAir = false,
    this.minRange = 0,
  });

  final String label;
  final int cost;
  final double range;
  final double cooldown;

  /// Damage of one shell. The mortar's comes from its blast instead.
  final double damage;
  final double shotSpeed;

  /// Aims at aircraft and drones first, and hits them hard.
  final bool antiAir;

  /// The mortar cannot fire at what is right next to it.
  final double minRange;

  static const maxLevel = 3;

  /// What the step from [level] to the next costs.
  int upgradeCost(int level) => (cost * 0.75 * level).round();

  double damageFactor(int level) => 1 + 0.35 * (level - 1);
  double rangeAt(int level) => range * (1 + 0.12 * (level - 1));
  double cooldownAt(int level) => cooldown * (1 - 0.15 * (level - 1));

  String get hint => switch (this) {
    TowerKind.cannon => 'gegen Panzer',
    TowerKind.flak => 'gegen Luftziele',
    TowerKind.mortar => 'Flächenfeuer',
  };
}

/// A gun emplacement a player put down. It never moves and can not be
/// destroyed. Only the client of its builder aims and fires it, everybody
/// else sees the shots as they come in.
class Tower extends PositionComponent with HasGameRef<SpaceGame> {
  Tower({
    required this.ownerId,
    required this.index,
    required this.color,
    required super.position,
    this.kind = TowerKind.cannon,
    this.level = 1,
  }) : super(size: Vector2.all(40), anchor: Anchor.center, priority: 8);

  final String ownerId;
  final int index;
  final Color color;
  final TowerKind kind;
  int level;

  String get id => '$ownerId#$index';

  double get range => kind.rangeAt(level);

  double turretAngle = 0;
  double _cooldown = 0;
  double _recoil = 0;
  double _think = 0;
  double _upgraded = 0;
  PositionComponent? _target;

  bool get _mine => ownerId == gameRef.myId;

  void fired(Vector2 direction) {
    turretAngle = atan2(direction.x, -direction.y);
    _recoil = 1;
  }

  void upgradeTo(int value) {
    if (value > level) {
      level = value;
      _upgraded = 1;
    }
  }

  @override
  void update(double dt) {
    _recoil = max(0, _recoil - dt * 6);
    _upgraded = max(0, _upgraded - dt);
    if (!_mine) {
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
    final aim = kind == TowerKind.mortar
        ? target.position.clone()
        : target.position +
              gameRef.velocityOfTarget(target) *
                  (target.position.distanceTo(position) / kind.shotSpeed);
    final wanted = atan2(aim.x - position.x, -(aim.y - position.y));
    final diff = (wanted - turretAngle).toNormalizedAngle();
    turretAngle += diff.clamp(-6 * dt, 6 * dt);
    if (diff.abs() < 0.08 && _cooldown <= 0) {
      _cooldown = kind.cooldownAt(level);
      if (kind == TowerKind.mortar) {
        gameRef.fireMortarTower(this, aim);
      } else {
        gameRef.fireTower(this);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    final base = Rect.fromCenter(center: c, width: 34, height: 34);
    canvas.drawRect(
      base.shift(const Offset(2, 3)),
      Paint()..color = const Color(0x55000000),
    );
    final concrete = switch (kind) {
      TowerKind.cannon => const Color(0xFF7A7A72),
      TowerKind.flak => const Color(0xFF6C7A86),
      TowerKind.mortar => const Color(0xFF85775F),
    };
    if (kind == TowerKind.mortar) {
      // Sandbags in a ring instead of a concrete block.
      canvas.drawCircle(c, 19, Paint()..color = const Color(0xFFB59B6B));
      canvas.drawCircle(c, 13, Paint()..color = concrete);
    } else {
      canvas.drawRect(base, Paint()..color = concrete);
      canvas.drawRect(
        base,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF2E2E2A),
      );
    }
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(turretAngle);
    final barrel = Paint()
      ..color = const Color(0xFF2E2E2A)
      ..strokeCap = StrokeCap.round;
    switch (kind) {
      case TowerKind.cannon:
        canvas.drawLine(
          Offset(0, 4 * _recoil),
          Offset(0, -26 + 4 * _recoil),
          barrel..strokeWidth = 6,
        );
      case TowerKind.flak:
        for (final x in const [-4.0, 4.0]) {
          canvas.drawLine(
            Offset(x, 2 * _recoil),
            Offset(x, -28 + 3 * _recoil),
            barrel..strokeWidth = 3,
          );
        }
      case TowerKind.mortar:
        canvas.drawLine(
          Offset(0, 2 * _recoil),
          Offset(0, -12 + 2 * _recoil),
          barrel..strokeWidth = 10,
        );
    }
    canvas.drawCircle(Offset.zero, 11, Paint()..color = color);
    canvas.drawCircle(
      Offset.zero,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = GameConfig.teamColors[1],
    );
    canvas.restore();
    // One chevron per level above the first.
    final pip = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Color.lerp(
        const Color(0xFFFFD54F),
        const Color(0xFFFFFFFF),
        _upgraded,
      )!;
    for (var i = 1; i < level; i++) {
      final y = size.y + 2 + i * 5.0;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - 7, y)
          ..lineTo(c.dx, y - 4)
          ..lineTo(c.dx + 7, y),
        pip,
      );
    }
  }
}
