import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../game_config.dart';
import '../special_weapon.dart';
import 'storm_zone.dart';

enum PowerUpType {
  repair('REPARATUR', Color(0xFF66BB6A)),
  smoke('NEBELWERFER', Color(0xFFB0BEC5)),
  rapidFire('SCHNELLFEUER', Color(0xFFFFB300)),

  /// Gems: refill the magazine or hand out a special weapon.
  ammo('MUNITION', Color(0xFF4FC3F7), gem: true),
  grenades('GRANATWERFER', Color(0xFFEF5350), gem: true),
  drone('DROHNE', Color(0xFFB388FF), gem: true);

  const PowerUpType(this.label, this.color, {this.gem = false});

  final String label;
  final Color color;

  /// Drawn as a gem instead of a crate.
  final bool gem;

  /// The special weapon this gem hands out, if any.
  SpecialWeapon? get weapon => switch (this) {
    PowerUpType.grenades => SpecialWeapon.grenades,
    PowerUpType.drone => SpecialWeapon.drone,
    _ => null,
  };

  /// Picks a type from a roll between 0 and 1. Ammo gems are the most common
  /// drop, since every shot costs a round.
  static PowerUpType fromRoll(double roll) {
    if (roll < 0.22) {
      return PowerUpType.repair;
    }
    if (roll < 0.36) {
      return PowerUpType.rapidFire;
    }
    if (roll < 0.48) {
      return PowerUpType.smoke;
    }
    if (roll < 0.78) {
      return PowerUpType.ammo;
    }
    if (roll < 0.9) {
      return PowerUpType.grenades;
    }
    return PowerUpType.drone;
  }
}

/// One planned crate: when it appears, where and what it holds. Derived from
/// the round seed alone, so every client sees the same crates without any
/// network traffic.
class PowerUpSlot {
  const PowerUpSlot({
    required this.id,
    required this.appearsAt,
    required this.position,
    required this.type,
  });

  final int id;
  final double appearsAt;
  final Vector2 position;
  final PowerUpType type;

  static List<PowerUpSlot> schedule(int seed) {
    final random = Random(seed ^ 0x5bd1e995);
    return [
      for (var i = 0; i < GameConfig.powerUpSlots; i++)
        () {
          final appearsAt =
              GameConfig.powerUpFirstAt + i * GameConfig.powerUpEvery;
          final startedAt = 0;
          final safe = StormZone.radiusAt(
            startedAt,
            startedAt + (appearsAt * 1000).round(),
          );
          final distance =
              sqrt(random.nextDouble()) * (safe - 60).clamp(80, 800);
          final direction = random.nextDouble() * 2 * pi;
          final roll = random.nextDouble();
          return PowerUpSlot(
            id: i,
            appearsAt: appearsAt,
            position: Vector2(cos(direction), sin(direction))..scale(distance),
            type: PowerUpType.fromRoll(roll),
          );
        }(),
    ];
  }
}

/// A crate lying on the field, picked up by driving over it.
class PowerUp extends PositionComponent {
  PowerUp({required this.slot})
    : super(
        position: slot.position.clone(),
        size: Vector2.all(36),
        anchor: Anchor.center,
        priority: 4,
      );

  final PowerUpSlot slot;
  PowerUpType get type => slot.type;
  double _time = 0;

  @override
  void onLoad() {
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    if (type.gem) {
      _renderGem(canvas);
      return;
    }
    final center = (size / 2).toOffset();
    final pulse = 1 + 0.08 * sin(_time * 4);
    final color = type.color;
    canvas.drawCircle(
      center,
      20 * pulse,
      Paint()..color = color.withValues(alpha: 0.25),
    );
    canvas.drawRect(
      Rect.fromCenter(center: center, width: 26, height: 26),
      Paint()..color = const Color(0xFF1E2614),
    );
    canvas.drawRect(
      Rect.fromCenter(center: center, width: 26, height: 26),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    switch (type) {
      case PowerUpType.repair:
        canvas.drawLine(center.translate(-7, 0), center.translate(7, 0), paint);
        canvas.drawLine(center.translate(0, -7), center.translate(0, 7), paint);
      case PowerUpType.rapidFire:
        for (final dy in [-5.0, 3.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(center.dx - 6, center.dy + dy + 4)
              ..lineTo(center.dx, center.dy + dy - 2)
              ..lineTo(center.dx + 6, center.dy + dy + 4),
            paint,
          );
        }
      case PowerUpType.smoke:
        final fill = Paint()..color = color;
        canvas.drawCircle(center.translate(-4, 2), 4.5, fill);
        canvas.drawCircle(center.translate(4, 2), 4.5, fill);
        canvas.drawCircle(center.translate(0, -3), 5, fill);
      case PowerUpType.ammo || PowerUpType.grenades || PowerUpType.drone:
        break;
    }
  }

  /// A cut stone floating above its shadow, with a glow and a glint running
  /// over the facets.
  void _renderGem(Canvas canvas) {
    final center = (size / 2).toOffset();
    final color = type.color;
    final bob = sin(_time * 3) * 2.5;
    final pulse = 1 + 0.1 * sin(_time * 4);
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 12), width: 20, height: 7),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawCircle(
      center.translate(0, bob),
      21 * pulse,
      Paint()..color = color.withValues(alpha: 0.22),
    );
    final c = center.translate(0, bob - 2);
    const w = 11.0;
    const top = 6.0;
    const bottom = 12.0;
    final crown = Path()
      ..moveTo(c.dx - w, c.dy)
      ..lineTo(c.dx - w * 0.5, c.dy - top)
      ..lineTo(c.dx + w * 0.5, c.dy - top)
      ..lineTo(c.dx + w, c.dy)
      ..close();
    final pavilion = Path()
      ..moveTo(c.dx - w, c.dy)
      ..lineTo(c.dx + w, c.dy)
      ..lineTo(c.dx, c.dy + bottom)
      ..close();
    canvas.drawPath(
      pavilion,
      Paint()..color = Color.lerp(color, const Color(0xFF000000), 0.35)!,
    );
    canvas.drawPath(
      crown,
      Paint()..color = Color.lerp(color, const Color(0xFFFFFFFF), 0.25)!,
    );
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xCCFFFFFF);
    canvas.drawPath(crown, edge);
    canvas.drawPath(pavilion, edge);
    canvas.drawLine(c.translate(-w * 0.5, -top), c.translate(0, bottom), edge);
    canvas.drawLine(c.translate(w * 0.5, -top), c.translate(0, bottom), edge);
    // A glint that sweeps across every two seconds.
    final glint = (_time % 2) / 2;
    if (glint < 0.35) {
      final x = c.dx - w + 2 * w * (glint / 0.35);
      canvas.drawCircle(
        Offset(x, c.dy - top * 0.5),
        2.2,
        Paint()..color = const Color(0xEEFFFFFF),
      );
    }
  }
}
