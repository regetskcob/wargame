import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/painting.dart';

import '../../game_config.dart';
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

  /// Set while the tank sits in smoke the viewer is not part of.
  bool hidden = false;

  /// A shield is up and swallows most of the damage.
  bool shielded = false;
  double _shieldTime = 0;

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
    _shieldTime += dt;
    bloodTimer = max(0, bloodTimer - dt);
    _recoil = max(0, _recoil - dt * 7);
    _muzzleFlash = max(0, _muzzleFlash - dt * 14);
    _leaveTrail(dt);
  }

  /// Track marks every few pixels travelled and dust once the tank is quick.
  void _leaveTrail(double dt) {
    final moved = position.distanceTo(_lastPosition);
    _lastPosition.setFrom(position);
    if (moved <= 0 || dt <= 0) {
      return;
    }
    final speed = moved / dt;
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
    paintTank(
      canvas,
      size.x,
      tankType,
      hull,
      turretAngle: (turretAngle - angle).toNormalizedAngle(),
      recoil: _recoil,
      flash: _muzzleFlash,
    );
    if (shielded) {
      final pulse = 0.5 + 0.5 * sin(_shieldTime * 5);
      final centre = Offset(size.x / 2, size.y / 2);
      canvas.drawCircle(
        centre,
        size.x * 0.78,
        Paint()..color = Color.fromRGBO(79, 195, 247, 0.12 + 0.08 * pulse),
      );
      canvas.drawCircle(
        centre,
        size.x * 0.78,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Color.fromRGBO(129, 212, 250, 0.5 + 0.4 * pulse),
      );
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
