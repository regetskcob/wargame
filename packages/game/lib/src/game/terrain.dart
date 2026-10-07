import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import 'bot_level.dart';
import 'map_theme.dart';

/// One hill, or with a negative [height] a hollow, shaped like a bell.
class Hill {
  const Hill(this.centre, this.radius, this.height);

  final Vector2 centre;
  final double radius;
  final double height;
}

/// The lie of the land. On the easy level the field is flat, from the middle
/// level on hills and hollows rise from the round seed, and on the hard
/// level there are more and steeper ones. Uphill a tank slows down, downhill
/// it rolls faster. Every client builds the same hills from the seed.
class Terrain {
  Terrain(this.hills);

  factory Terrain.forSeed(
    int seed,
    BotLevel level, {
    required Rect area,
    Iterable<Vector2> keepClear = const [],
  }) {
    final (count, steepness) = switch (level) {
      BotLevel.easy => (0, 0.0),
      BotLevel.normal => (7, 1.0),
      BotLevel.hard => (13, 1.45),
    };
    final random = Random(seed ^ 0x7e11a);
    final hills = <Hill>[];
    var attempts = 0;
    while (hills.length < count && attempts < count * 20) {
      attempts++;
      final centre = Vector2(
        area.left + random.nextDouble() * area.width,
        area.top + random.nextDouble() * area.height,
      );
      final radius = 150 + random.nextDouble() * 170;
      if (keepClear.any((p) => p.distanceTo(centre) < radius * 0.6) ||
          hills.any((h) => h.centre.distanceTo(centre) < h.radius * 0.8)) {
        continue;
      }
      // One in four is a hollow.
      final sign = random.nextDouble() < 0.25 ? -0.7 : 1.0;
      final height = sign * steepness * (0.7 + random.nextDouble() * 0.5);
      hills.add(Hill(centre, radius, height));
    }
    return Terrain(hills);
  }

  static final flat = Terrain(const []);

  final List<Hill> hills;

  bool get isFlat => hills.isEmpty;

  double heightAt(Vector2 at) {
    var sum = 0.0;
    for (final hill in hills) {
      final d2 = at.distanceToSquared(hill.centre);
      sum += hill.height * exp(-d2 / (hill.radius * hill.radius));
    }
    return sum;
  }

  /// How fast the ground rises at [at], per world unit, in each direction.
  Vector2 slopeAt(Vector2 at) {
    final slope = Vector2.zero();
    for (final hill in hills) {
      final offset = at - hill.centre;
      final r2 = hill.radius * hill.radius;
      final e = hill.height * exp(-offset.length2 / r2);
      slope.add(offset * (-2 * e / r2));
    }
    return slope;
  }

  /// Factor on the top speed of a tank at [at] heading along [direction]:
  /// below 1 uphill, above 1 downhill.
  double speedFactor(Vector2 at, Vector2 direction) {
    if (hills.isEmpty) {
      return 1;
    }
    final climb = slopeAt(at).dot(direction) * 150;
    return (1 - climb).clamp(0.6, 1.3);
  }
}

/// Draws the hills: lit from the upper left, shaded to the lower right, with
/// faint contour lines, and some grass and stones on top for the eye.
class TerrainLayer extends PositionComponent {
  TerrainLayer({required this.terrain, required this.theme, required int seed})
    : super(priority: -19) {
    final random = Random(seed ^ 0x6a55);
    for (final hill in terrain.hills) {
      for (var i = 0; i < 14; i++) {
        final a = random.nextDouble() * 2 * pi;
        final d = sqrt(random.nextDouble()) * hill.radius * 0.9;
        _tufts.add((
          (hill.centre + Vector2(cos(a), sin(a)) * d).toOffset(),
          2 + random.nextDouble() * 3,
          random.nextDouble() < 0.3,
        ));
      }
    }
  }

  final Terrain terrain;
  final MapTheme theme;
  final _tufts = <(Offset, double, bool)>[];

  @override
  void render(Canvas canvas) {
    for (final hill in terrain.hills) {
      final c = hill.centre.toOffset();
      final r = hill.radius;
      final up = hill.height > 0;
      final strength = hill.height.abs().clamp(0.0, 1.6);
      // Light on the side facing the sun, shadow on the far side.
      final lit = c + Offset(-r * 0.25, -r * 0.25) * (up ? 1 : -1);
      final shade = c + Offset(r * 0.25, r * 0.25) * (up ? 1 : -1);
      canvas.drawCircle(
        lit,
        r * 0.95,
        Paint()
          ..shader = Gradient.radial(lit, r * 0.95, [
            Color.fromRGBO(255, 248, 220, 0.2 * strength),
            const Color(0x00FFF8DC),
          ]),
      );
      canvas.drawCircle(
        shade,
        r,
        Paint()
          ..shader = Gradient.radial(shade, r, [
            Color.fromRGBO(0, 0, 0, 0.26 * strength),
            const Color(0x00000000),
          ]),
      );
      // Faint contours at two heights, enough to read the shape.
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Color.fromRGBO(0, 0, 0, up ? 0.06 : 0.09);
      for (final level in const [0.4, 0.75]) {
        canvas.drawCircle(c, r * sqrt(-log(level)), line);
      }
    }
    final grass = Paint()
      ..strokeWidth = 1.3
      ..color = theme.treeInner.withValues(alpha: 0.55);
    final stone = Paint()..color = theme.debris.withValues(alpha: 0.6);
    for (final (at, size, isStone) in _tufts) {
      if (isStone) {
        canvas.drawOval(
          Rect.fromCenter(center: at, width: size * 2, height: size * 1.4),
          stone,
        );
      } else {
        canvas.drawLine(at, at.translate(-size * 0.6, -size), grass);
        canvas.drawLine(at, at.translate(0, -size * 1.3), grass);
        canvas.drawLine(at, at.translate(size * 0.6, -size), grass);
      }
    }
  }
}
