import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../game_config.dart';

/// A cloud that hides every tank inside it from players standing outside.
class SmokeCloud extends PositionComponent {
  SmokeCloud({required super.position})
    : super(
        size: Vector2.all(GameConfig.smokeRadius * 2),
        anchor: Anchor.center,
        priority: 20,
      );

  double _age = 0;

  bool covers(Vector2 point) =>
      point.distanceTo(position) <= GameConfig.smokeRadius;

  double get _fade {
    final left = GameConfig.smokeSeconds - _age;
    return (min(_age / 0.6, left / 1.5)).clamp(0.0, 1.0);
  }

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= GameConfig.smokeSeconds) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final radius = GameConfig.smokeRadius;
    final center = (size / 2).toOffset();
    final fade = _fade;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF8E9690).withValues(alpha: 0.88 * fade),
    );
    final puff = Paint();
    for (var i = 0; i < 9; i++) {
      final a = i * 2 * pi / 9 + _age * (i.isEven ? 0.25 : -0.2);
      final r = radius * (0.45 + 0.1 * sin(_age * 1.5 + i));
      puff.color = const Color(0xFFB4BBB5).withValues(alpha: 0.7 * fade);
      canvas.drawCircle(
        center.translate(cos(a) * r, sin(a) * r),
        radius * 0.38,
        puff,
      );
    }
  }
}
