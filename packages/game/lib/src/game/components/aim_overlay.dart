import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../game_config.dart';
import '../game_phase.dart';
import '../special_weapon.dart';
import '../space_game.dart';

/// Shows where the gun points: a dotted line out of the barrel as far as the
/// shells fly, and a crosshair where the mouse is.
class AimOverlay extends Component with HasGameRef<SpaceGame> {
  AimOverlay() : super(priority: 30);

  @override
  void render(Canvas canvas) {
    final game = gameRef;
    final ship = game.myShip;
    if (game.phase.value != GamePhase.playing ||
        ship == null ||
        !ship.isMounted) {
      return;
    }
    final range = ship.stats.bulletSpeed * GameConfig.bulletTtl;
    final direction = ship.turretDirection;
    final muzzle = ship.position + direction * (GameConfig.shipRadius + 16);

    // Barrel line, dotted, fading out towards the end of the range.
    const dots = 22;
    for (var i = 1; i <= dots; i++) {
      final t = i / dots;
      final p = muzzle + direction * (range * t);
      canvas.drawCircle(
        Offset(p.x, p.y),
        1.6,
        Paint()..color = Color.fromRGBO(255, 179, 0, 0.75 * (1 - t * 0.8)),
      );
    }

    final point = game.pointerWorld();
    if (ship.special == SpecialWeapon.grenades) {
      _grenadeRing(canvas, ship.position, direction, point, game.touch.aim);
    }
    if (point == null || game.touch.aim != null) {
      return;
    }
    final inRange = point.distanceTo(ship.position) <= range;
    final color = inRange ? const Color(0xFFFFB300) : const Color(0xAAFFFFFF);
    final c = Offset(point.x, point.y);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = color;
    canvas.drawCircle(c, 9, line);
    for (final a in [0.0, pi / 2, pi, 3 * pi / 2]) {
      canvas.drawLine(
        c + Offset(cos(a) * 5, sin(a) * 5),
        c + Offset(cos(a) * 14, sin(a) * 14),
        line,
      );
    }
  }

  /// Where a grenade would land right now, with its blast radius.
  void _grenadeRing(
    Canvas canvas,
    Vector2 from,
    Vector2 direction,
    Vector2? pointer,
    double? stick,
  ) {
    final wanted = stick != null
        ? GameConfig.grenadeRange * 0.75
        : pointer?.distanceTo(from) ?? GameConfig.grenadeRange;
    final distance = wanted.clamp(
      GameConfig.grenadeMinRange,
      GameConfig.grenadeRange,
    );
    final at = from + direction * distance;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0x99EF5350);
    const dashes = 24;
    for (var i = 0; i < dashes; i++) {
      final a = 2 * pi * i / dashes;
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(at.x, at.y),
          radius: GameConfig.grenadeRadius,
        ),
        a,
        pi / dashes,
        false,
        paint,
      );
    }
  }
}
