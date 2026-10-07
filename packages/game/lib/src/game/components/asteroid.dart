import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../map_theme.dart';

/// A patch of woods, boulders or rubble. It slows tanks and stops shells
/// until enough shells have cut it down to a stump.
class Asteroid extends PositionComponent {
  Asteroid({
    required this.index,
    required super.position,
    required this.radius,
    required this.vertices,
    required super.angle,
    this.theme = MapTheme.forest,
  }) : super(size: Vector2.all(radius * 2), anchor: Anchor.center);

  /// Position in the field's list of trees, the same on every client.
  final int index;
  final double radius;
  final List<Vector2> vertices;
  final MapTheme theme;

  /// Bigger trees take more shells.
  late double hp = maxHp;
  double get maxHp => radius * 2.2;

  /// Cut down: no longer slows tanks or stops shells.
  bool get felled => hp <= 0;

  late final Path _outline = () {
    final path = Path();
    for (var i = 0; i < vertices.length; i++) {
      final vertex = vertices[i] + size / 2;
      if (i == 0) {
        path.moveTo(vertex.x, vertex.y);
      } else {
        path.lineTo(vertex.x, vertex.y);
      }
    }
    path.close();
    return path;
  }();

  @override
  void onLoad() {
    add(
      CircleHitbox(
        radius: radius * 0.8,
        position: size / 2,
        anchor: Anchor.center,
      ),
    );
  }

  /// Sets the health, returns true when this cut the tree down.
  bool setHp(double value) {
    final wasStanding = !felled;
    hp = value;
    return wasStanding && felled;
  }

  @override
  void render(Canvas canvas) {
    if (felled) {
      // Stump and a few splinters.
      final centre = (size / 2).toOffset();
      canvas.drawCircle(
        centre,
        radius * 0.28,
        Paint()..color = theme.treeEdge.withValues(alpha: 0.85),
      );
      canvas.drawCircle(
        centre,
        radius * 0.18,
        Paint()..color = theme.debris.withValues(alpha: 0.9),
      );
      return;
    }
    canvas.drawPath(_outline, Paint()..color = theme.treeOuter);
    canvas.save();
    canvas.translate(size.x * 0.06, size.y * 0.06);
    canvas.scale(0.8);
    canvas.drawPath(_outline, Paint()..color = theme.treeInner);
    canvas.restore();
    canvas.drawPath(
      _outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = theme.treeEdge,
    );
  }
}
