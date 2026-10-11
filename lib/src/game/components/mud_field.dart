import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../game_config.dart';
import '../island_shape.dart';
import '../map_theme.dart';
import 'static_picture.dart';

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
class MudField extends Component with StaticPicture {
  MudField({required this.seed, required this.theme})
    : islands = theme.islands ? IslandShape.forSeed(seed) : null,
      super(priority: -18) {
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

  /// The land of the islands map; everything else in the field is water.
  final IslandShape? islands;

  /// The shores of [islands], worked out once for the field and the map.
  late final List<Path> shores = islands?.outlines() ?? const [];

  /// Top speed in soft ground: wading through the shallows is slower than
  /// mud.
  double get slowdown => islands == null ? 0.6 : 0.45;

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
    if (islands case final shape?) {
      return shape.shallow(point);
    }
    for (final patch in patches) {
      if (patch.centre.distanceTo(point) < patch.radius * 0.85) {
        return true;
      }
    }
    return false;
  }

  /// The patches never change in a round: recorded once.
  @override
  void render(Canvas canvas) => renderStatic(canvas);

  @override
  void paintStatic(Canvas canvas) {
    if (islands case final shape?) {
      _paintWater(canvas, shape);
      return;
    }
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

  /// Deep water over the whole ground, the lighter shallows along the
  /// shores, the land cut out of both with a beach of sand, the bridges
  /// on top and a few ripples.
  void _paintWater(Canvas canvas, IslandShape shape) {
    Path union(Iterable<Path> paths) => paths.fold(
      Path(),
      (all, path) => Path.combine(PathOperation.union, all, path),
    );
    final land = union(shores);
    final wade = union(shape.outlines(grow: IslandShape.shallows));
    final sea = Path.combine(
      PathOperation.difference,
      Path()..addOval(
        Rect.fromCircle(center: Offset.zero, radius: GameConfig.groundReach),
      ),
      wade,
    );
    canvas.drawPath(sea, Paint()..color = theme.mud);
    canvas.drawPath(
      Path.combine(PathOperation.difference, wade, land),
      Paint()..color = Color.lerp(theme.mud, const Color(0xFFBFE3E8), 0.35)!,
    );
    canvas.drawPath(
      land,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = theme.mudRim,
    );
    final ripple = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x33FFFFFF);
    final random = Random(seed ^ 0x51de);
    for (var i = 0; i < 90; i++) {
      final at = Vector2(
        (random.nextDouble() * 2 - 1) * GameConfig.worldRadius,
        (random.nextDouble() * 2 - 1) * GameConfig.worldRadius,
      );
      if (!shape.deep(at)) {
        continue;
      }
      canvas.drawArc(
        Rect.fromCenter(center: Offset(at.x, at.y), width: 26, height: 8),
        pi * 1.1,
        pi * 0.8,
        false,
        ripple,
      );
    }
    for (final bridge in shape.bridges) {
      _paintBridge(canvas, bridge);
    }
  }

  /// Planks across, a rail along either side.
  static void _paintBridge(Canvas canvas, IslandBridge bridge) {
    canvas.save();
    canvas.translate(bridge.start.x, bridge.start.y);
    canvas.rotate(atan2(bridge.along.y, bridge.along.x));
    const half = IslandBridge.halfWidth;
    final length = bridge.length;
    canvas.drawRect(
      Rect.fromLTRB(0, -half, length, half),
      Paint()..color = const Color(0xFF8A6A44),
    );
    final seam = Paint()
      ..color = const Color(0xFF5E4528)
      ..strokeWidth = 1.4;
    for (var x = 6.0; x < length; x += 9) {
      canvas.drawLine(Offset(x, -half), Offset(x, half), seam);
    }
    final rail = Paint()..color = const Color(0xFF4A3520);
    canvas.drawRect(Rect.fromLTRB(0, -half - 3, length, -half + 1), rail);
    canvas.drawRect(Rect.fromLTRB(0, half - 1, length, half + 3), rail);
    canvas.restore();
  }
}
