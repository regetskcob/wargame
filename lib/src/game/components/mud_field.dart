import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../game_config.dart';
import '../map_theme.dart';

/// One patch of soft ground.
class MudPatch {
  const MudPatch(this.centre, this.radius, this.blob);

  final Vector2 centre;
  final double radius;
  final Path blob;
}

/// Swamp, quicksand, deep snow or puddles, depending on the map. Tanks inside
/// a patch drive slower. The patches follow from the round seed, so every
/// client agrees on them without network traffic.
class MudField extends Component {
  MudField({required this.seed, required this.theme}) : super(priority: -18) {
    final random = Random(seed ^ 0x2f6b);
    var attempts = 0;
    while (patches.length < theme.mudCount && attempts < 300) {
      attempts++;
      final radius = 55 + random.nextDouble() * 55;
      final distance = 90 + random.nextDouble() * 680;
      final direction = random.nextDouble() * 2 * pi;
      final centre = Vector2(cos(direction), sin(direction))..scale(distance);
      // Leave the ring where the tanks start free and do not stack patches.
      if ((distance - GameConfig.spawnRadius).abs() < radius + 50) {
        continue;
      }
      if (patches.any((p) => p.centre.distanceTo(centre) < p.radius + radius)) {
        continue;
      }
      patches.add(MudPatch(centre, radius, _blob(random, radius)));
    }
  }

  final int seed;
  final MapTheme theme;
  final patches = <MudPatch>[];

  static Path _blob(Random random, double radius) {
    const points = 14;
    final offsets = [
      for (var i = 0; i < points; i++)
        Offset(
          cos(2 * pi * i / points),
          sin(2 * pi * i / points),
        ).scale(radius * (0.8 + random.nextDouble() * 0.25), radius * 0.85),
    ];
    final path = Path()
      ..moveTo(
        (offsets.last.dx + offsets.first.dx) / 2,
        (offsets.last.dy + offsets.first.dy) / 2,
      );
    for (var i = 0; i < points; i++) {
      final next = offsets[(i + 1) % points];
      path.quadraticBezierTo(
        offsets[i].dx,
        offsets[i].dy,
        (offsets[i].dx + next.dx) / 2,
        (offsets[i].dy + next.dy) / 2,
      );
    }
    return path..close();
  }

  bool softAt(Vector2 point) {
    for (final patch in patches) {
      if (patch.centre.distanceTo(point) < patch.radius * 0.85) {
        return true;
      }
    }
    return false;
  }

  @override
  void render(Canvas canvas) {
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = theme.mudRim.withValues(alpha: 0.7);
    final fill = Paint()..color = theme.mud.withValues(alpha: 0.9);
    final speck = Paint()..color = theme.mudRim.withValues(alpha: 0.45);
    for (final patch in patches) {
      canvas.save();
      canvas.translate(patch.centre.x, patch.centre.y);
      canvas.drawPath(patch.blob, fill);
      canvas.drawPath(patch.blob, rim);
      final random = Random(patch.centre.x.round());
      for (var i = 0; i < 6; i++) {
        final a = random.nextDouble() * 2 * pi;
        final r = random.nextDouble() * patch.radius * 0.6;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cos(a) * r, sin(a) * r),
            width: 10 + random.nextDouble() * 14,
            height: 5 + random.nextDouble() * 8,
          ),
          speck,
        );
      }
      canvas.restore();
    }
  }
}
