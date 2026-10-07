import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/painting.dart';

import '../../game_config.dart';
import '../tank_damage.dart';
import '../tank_stats.dart';
import 'effects.dart';
import 'tank_painter.dart';

/// A tank seen from above, in the paint scheme and shape the player picked.
abstract class ShipBase extends PositionComponent {
  ShipBase({
    required this.playerId,
    required this.playerName,
    required this.shipColor,
    required this.tankType,
    required super.position,
    super.angle,
  }) : super(
         size: Vector2.all(GameConfig.shipRadius * 2),
         anchor: Anchor.center,
         priority: 10,
       );

  final String playerId;
  final String playerName;
  final Color shipColor;
  final TankType tankType;

  late final TankStats stats = TankStats.of(tankType);
  late double hp = stats.maxHp;

  /// World angle of the turret. It follows the hull until somebody aims.
  late double turretAngle = angle;

  /// 0 plays alone, 1 is red, 2 is blue.
  int team = 0;

  /// Seconds the tracks still print red after rolling over a soldier.
  double bloodTimer = 0;
  double _recoil = 0;
  double _muzzleFlash = 0;
  double _trailDistance = 0;
  double _dustTimer = 0;
  late final Vector2 _lastPosition = position.clone();
  TrackLayer? _tracks;
  double _flashTime = 0;

  /// Running clock for the smoke, the fire and the rattling hull.
  double _clock = 0;
  double _smokeTimer = 0;
  double _groundSpeed = 0;

  /// Kick of the last hit, 0 to 1, fades within a fraction of a second.
  double _jolt = 0;
  double _joltAngle = 0;
  static final _random = Random();

  /// Seed for the scars, so a tank keeps its own pattern.
  late final int _scarSeed = playerId.hashCode;

  TankDamage get damage => TankDamage.of(hp, stats.maxHp);

  /// Set while the tank sits in smoke the viewer is not part of.
  bool hidden = false;

  Vector2 get direction => Vector2(sin(angle), -cos(angle));

  Vector2 get turretDirection => Vector2(sin(turretAngle), -cos(turretAngle));

  @override
  void onLoad() {
    add(ShipTag());
  }

  @override
  void onMount() {
    super.onMount();
    _tracks = parent?.children.whereType<TrackLayer>().firstOrNull;
  }

  void flash() {
    _flashTime = 0.15;
  }

  /// Visible reaction to a hit of [amount]: the white flash, the hull
  /// knocked aside and sparks flying off the armour.
  void takeHitEffects(double amount) {
    flash();
    if (amount < 2) {
      return;
    }
    _jolt = min(1.0, _jolt + 0.3 + amount / 40);
    _joltAngle = _random.nextDouble() * 2 * pi;
    if (!hidden) {
      parent?.add(
        puff(
          position: jitter(position, size.x * 0.25),
          color: const Color(0xFFFFC46B),
          count: 4 + (amount / 6).round().clamp(0, 6),
          lifespan: 0.35,
          speed: (40, 120),
          size: (1, 2.2),
          opacity: 0.95,
          priority: 17,
        ),
      );
    }
  }

  /// Muzzle flash, recoil and a puff of powder smoke at the barrel tip.
  void fireEffects() {
    _recoil = 1;
    _muzzleFlash = 1;
    final tip =
        position +
        Vector2(sin(turretAngle), -cos(turretAngle)) * (size.x * 0.85);
    parent?.add(
      puff(
        position: tip,
        color: const Color(0xFFB8B8B0),
        count: 5,
        lifespan: 0.8,
        speed: (10, 40),
        size: (3, 7),
        opacity: 0.55,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flashTime > 0) {
      _flashTime -= dt;
    }
    bloodTimer = max(0, bloodTimer - dt);
    _recoil = max(0, _recoil - dt * 7);
    _muzzleFlash = max(0, _muzzleFlash - dt * 14);
    _jolt = max(0, _jolt - dt * 5);
    _clock += dt;
    _leaveTrail(dt);
    _smoke(dt);
  }

  /// A short shove of the hull, from a pothole or a broken track link.
  void bump(double strength) {
    _jolt = min(1.0, _jolt + strength);
    _joltAngle = _random.nextDouble() * 2 * pi;
  }

  /// The engine misfires and coughs out a dark cloud.
  void backfire() {
    if (hidden) {
      return;
    }
    parent?.add(
      puff(
        position: jitter(position - direction * (size.x * 0.45), 3),
        color: const Color(0xFF151413),
        count: 4,
        lifespan: 1.1,
        speed: (10, 34),
        size: (5, 10),
        opacity: 0.75,
        priority: 15,
      ),
    );
  }

  /// A damaged engine smokes, a burning one belches black clouds and embers.
  void _smoke(double dt) {
    final interval = damage.smokeInterval;
    if (interval == null || hidden || hp <= 0) {
      return;
    }
    _smokeTimer -= dt;
    if (_smokeTimer > 0) {
      return;
    }
    _smokeTimer = interval * (0.7 + _random.nextDouble() * 0.6);
    final stage = damage.stage;
    final deck = position - direction * (size.x * 0.32);
    final burning = stage == DamageStage.burning;
    parent?.add(
      puff(
        position: jitter(deck, 4),
        color: burning
            ? const Color(0xFF1E1C1A)
            : stage == DamageStage.crippled
            ? const Color(0xFF4A4744)
            : const Color(0xFF8A8782),
        count: burning ? 3 : 2,
        lifespan: burning ? 1.6 : 1.2,
        speed: (8, 26),
        size: burning ? (6, 12) : (4, 9),
        opacity: burning ? 0.7 : 0.45,
        priority: 15,
      ),
    );
    if (burning && _random.nextDouble() < 0.4) {
      parent?.add(
        puff(
          position: jitter(deck, 3),
          color: const Color(0xFFFF8F00),
          count: 2,
          lifespan: 0.5,
          speed: (20, 60),
          size: (0.8, 1.8),
          opacity: 0.9,
          priority: 17,
        ),
      );
    }
  }

  /// Track marks every few pixels travelled and dust once the tank is quick.
  void _leaveTrail(double dt) {
    final moved = position.distanceTo(_lastPosition);
    _lastPosition.setFrom(position);
    if (moved <= 0 || dt <= 0) {
      _groundSpeed = 0;
      return;
    }
    final speed = moved / dt;
    _groundSpeed = speed;
    _trailDistance += moved;
    if (_trailDistance > 9) {
      _trailDistance = 0;
      final side = Vector2(cos(angle), sin(angle)) * (size.x * 0.27);
      final back = Vector2(sin(angle), -cos(angle)) * (size.x * 0.1);
      _tracks?.addMarks(
        position - side - back,
        position + side - back,
        angle,
        bloody: bloodTimer > 0,
      );
    }
    _dustTimer -= dt;
    if (speed > 55 && _dustTimer <= 0) {
      _dustTimer = 0.11;
      final rear = position - Vector2(sin(angle), -cos(angle)) * (size.x * 0.5);
      parent?.add(
        puff(
          position: jitter(rear, 6),
          color: const Color(0xFFB59B6B),
          count: 3,
          lifespan: 0.9,
          speed: (5, 22),
          size: (4, 9),
          opacity: min(0.5, speed / 400),
          priority: 9,
        ),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    if (hidden) {
      return;
    }
    if (team > 0) {
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x * 0.66,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..color = GameConfig.teamColors[team].withValues(alpha: 0.75),
      );
    }
    final hull = _flashTime > 0 ? const Color(0xFFFFFFFF) : shipColor;
    final damage = this.damage;
    // A battered running gear rattles the hull on the move, and every hit
    // shoves the tank aside for a moment.
    final rattle =
        damage.bumpiness * 1.6 * min(1.0, _groundSpeed / 90) + _jolt * 3;
    final shifted = rattle > 0.05;
    if (shifted) {
      canvas.save();
      canvas.translate(
        (_random.nextDouble() * 2 - 1) * rattle * 0.5 +
            cos(_joltAngle) * _jolt * 3,
        (_random.nextDouble() * 2 - 1) * rattle * 0.5 +
            sin(_joltAngle) * _jolt * 3,
      );
    }
    paintTank(
      canvas,
      size.x,
      tankType,
      hull,
      turretAngle: (turretAngle - angle).toNormalizedAngle(),
      recoil: _recoil,
      flash: _muzzleFlash,
      wear: damage.wear,
      scarSeed: _scarSeed,
      flame: damage.stage == DamageStage.burning ? _clock : null,
    );
    if (shifted) {
      canvas.restore();
    }
  }
}

class ShipTag extends PositionComponent {
  ShipTag() : super(anchor: Anchor.center);

  static final _namePaints = [
    for (final color in GameConfig.teamColors)
      TextPaint(style: TextStyle(color: color, fontSize: 11)),
  ];

  ShipBase get ship => parent! as ShipBase;

  @override
  void onMount() {
    super.onMount();
    position = ship.size / 2;
  }

  @override
  void update(double dt) {
    angle = -ship.angle;
  }

  @override
  void render(Canvas canvas) {
    if (ship.hidden) {
      return;
    }
    final ratio = (ship.hp / ship.stats.maxHp).clamp(0.0, 1.0);
    const barWidth = 36.0;
    final barTop = ship.size.y / 2 + 6;
    canvas.drawRect(
      Rect.fromLTWH(-barWidth / 2, barTop, barWidth, 4),
      Paint()..color = const Color(0x66000000),
    );
    canvas.drawRect(
      Rect.fromLTWH(-barWidth / 2, barTop, barWidth * ratio, 4),
      Paint()
        ..color = ratio > 0.3
            ? const Color(0xFF9CCC65)
            : const Color(0xFFD1492E),
    );
    _namePaints[ship.team].render(
      canvas,
      ship.playerName,
      Vector2(0, barTop + 6),
      anchor: Anchor.topCenter,
    );
  }
}
