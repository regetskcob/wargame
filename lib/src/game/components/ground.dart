import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../game_config.dart';
import '../map_theme.dart';

/// The ground of a map: patches of colour and a ring where the tanks start.
/// City maps are paved and cut by two roads.
class Ground extends PositionComponent {
  Ground(this.theme, {this.plain = false}) : super(priority: -20) {
    final random = Random(7);
    _patches = [
      for (var i = 0; i < 480; i++)
        (
          Offset(
            (random.nextDouble() * 2 - 1) * GameConfig.groundReach,
            (random.nextDouble() * 2 - 1) * GameConfig.groundReach,
          ),
          30 + random.nextDouble() * 90,
          theme.patches[random.nextInt(theme.patches.length)].withValues(
            alpha: 0.55,
          ),
        ),
    ];
  }

  final MapTheme theme;

  /// Without the start ring and the crossroads, for the defense map that
  /// brings its own road.
  final bool plain;
  late final List<(Offset, double, Color)> _patches;

  @override
  void render(Canvas canvas) {
    const reach = GameConfig.groundReach;
    canvas.drawRect(
      Rect.fromCircle(center: Offset.zero, radius: reach),
      Paint()..color = theme.ground,
    );
    for (final (offset, patchRadius, color) in _patches) {
      canvas.drawOval(
        Rect.fromCenter(
          center: offset,
          width: patchRadius * 2,
          height: patchRadius * 1.4,
        ),
        Paint()..color = color,
      );
    }
    if (plain) {
      return;
    }
    if (theme.roads) {
      _paintRoads(canvas, reach);
    }
    canvas.drawCircle(
      Offset.zero,
      GameConfig.spawnRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..color = theme.ring,
    );
  }

  void _paintRoads(Canvas canvas, double reach) {
    final joints = Paint()
      ..strokeWidth = 1
      ..color = const Color(0x22000000);
    for (var v = -reach; v <= reach; v += 120) {
      canvas.drawLine(Offset(v, -reach), Offset(v, reach), joints);
      canvas.drawLine(Offset(-reach, v), Offset(reach, v), joints);
    }
    final asphalt = Paint()..color = const Color(0xFF2B2D30);
    canvas.drawRect(Rect.fromLTRB(-reach, -34, reach, 34), asphalt);
    canvas.drawRect(Rect.fromLTRB(-34, -reach, 34, reach), asphalt);
    final dash = Paint()
      ..strokeWidth = 3
      ..color = const Color(0xCCD9C14A);
    for (var v = -reach; v < reach; v += 56) {
      canvas.drawLine(Offset(v, 0), Offset(v + 28, 0), dash);
      canvas.drawLine(Offset(0, v), Offset(0, v + 28), dash);
    }
  }
}
