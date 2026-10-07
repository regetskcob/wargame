import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../map_theme.dart';

class Asteroid extends PositionComponent {
  Asteroid({
    required super.position,
    required this.radius,
    required this.vertices,
    required super.angle,
    this.theme = MapTheme.forest,
  }) : super(size: Vector2.all(radius * 2), anchor: Anchor.center);

  final double radius;
  final List<Vector2> vertices;
  final MapTheme theme;

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

  @override
  void render(Canvas canvas) {
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
