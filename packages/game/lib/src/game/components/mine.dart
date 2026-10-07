import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../game_config.dart';

/// A mine on the ground. It arms a moment after it was laid and goes off
/// under the first enemy tank that drives over it. Its owner and their team
/// see it clearly, everybody else only as a faint shape in the dirt.
class Mine extends PositionComponent {
  Mine({
    required this.mineId,
    required this.ownerId,
    required this.friendly,
    required super.position,
  }) : super(
         size: Vector2.all(GameConfig.mineRadius * 2),
         anchor: Anchor.center,
         priority: 3,
       );

  final String mineId;
  final String ownerId;

  /// Laid by the local player or a teammate.
  final bool friendly;

  double _age = 0;

  bool get armed => _age >= GameConfig.mineArmSeconds;

  @override
  void onLoad() {
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    _age += dt;
  }

  @override
  void render(Canvas canvas) {
    final center = (size / 2).toOffset();
    final alpha = friendly ? 1.0 : 0.28;
    canvas.drawCircle(
      center,
      9,
      Paint()..color = Color.fromRGBO(34, 34, 30, alpha),
    );
    canvas.drawCircle(
      center,
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Color.fromRGBO(90, 88, 78, alpha),
    );
    for (var i = 0; i < 4; i++) {
      final a = i * pi / 2 + pi / 4;
      canvas.drawCircle(
        center + Offset(cos(a), sin(a)) * 5,
        1.4,
        Paint()..color = Color.fromRGBO(110, 108, 96, alpha),
      );
    }
    if (friendly) {
      final blink = armed && (_age * 2).floor().isEven;
      canvas.drawCircle(
        center,
        2.2,
        Paint()
          ..color = blink
              ? const Color(0xFFFF3B2F)
              : armed
              ? const Color(0xFF6B1A14)
              : const Color(0xFFFFC107),
      );
    }
  }
}
