import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:flame/components.dart';

import '../game_config.dart';

class StormZone extends PositionComponent {
  StormZone({required this.startedAt}) : super(priority: -10);

  final int startedAt;

  /// Seconds after the start when the zone reaches [GameConfig.zoneMinRadius].
  static const closedAfter =
      GameConfig.zoneGraceSeconds + GameConfig.zoneShrinkSeconds;

  /// Seconds after the start when the closed zone starts to draw in again.
  static const finalAfter = closedAfter + GameConfig.zoneHoldSeconds;

  static double radiusAt(int startedAt, int nowMs) {
    final elapsed = (nowMs - startedAt) / 1000;
    if (elapsed < GameConfig.zoneGraceSeconds) {
      return GameConfig.worldRadius;
    }
    if (elapsed >= finalAfter) {
      final progress = ((elapsed - finalAfter) / GameConfig.zoneFinalSeconds)
          .clamp(0.0, 1.0);
      return GameConfig.zoneMinRadius * (1 - progress);
    }
    final progress =
        ((elapsed - GameConfig.zoneGraceSeconds) / GameConfig.zoneShrinkSeconds)
            .clamp(0.0, 1.0);
    return GameConfig.worldRadius +
        (GameConfig.zoneMinRadius - GameConfig.worldRadius) * progress;
  }

  /// Damage per second outside the zone: steady while it closes, then
  /// rising for every second it has been closed.
  static double damageAt(int startedAt, int nowMs) {
    final closed = (nowMs - startedAt) / 1000 - closedAfter;
    return GameConfig.zoneDamagePerSecond +
        (closed > 0 ? closed * GameConfig.zoneDamageRampPerSecond : 0);
  }

  double get radius => radiusAt(startedAt, clock.now().millisecondsSinceEpoch);

  @override
  void render(Canvas canvas) {
    final safeRadius = radius;
    final outer = GameConfig.groundReach;
    final storm = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromCircle(center: Offset.zero, radius: outer))
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: safeRadius));
    canvas.drawPath(storm, Paint()..color = const Color(0x44B8860B));
    canvas.drawCircle(
      Offset.zero,
      safeRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xCCFFB300),
    );
    canvas.drawCircle(
      Offset.zero,
      GameConfig.worldRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x55FFFFFF),
    );
  }
}
