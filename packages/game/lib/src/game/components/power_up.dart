import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../game_config.dart';
import 'storm_zone.dart';

enum PowerUpType {
  repair('REPARATUR', Color(0xFF66BB6A)),
  smoke('NEBELWERFER', Color(0xFFB0BEC5)),
  rapidFire('SCHNELLFEUER', Color(0xFFFFB300));

  const PowerUpType(this.label, this.color);

  final String label;
  final Color color;
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
            type: roll < 0.4
                ? PowerUpType.repair
                : roll < 0.7
                ? PowerUpType.rapidFire
                : PowerUpType.smoke,
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
    }
  }
}
