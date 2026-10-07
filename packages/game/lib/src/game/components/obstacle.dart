import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../map_theme.dart';
import 'explosion.dart';

/// A solid object that blocks tanks and shells until it is shot to pieces.
abstract class Obstacle extends PositionComponent {
  Obstacle({
    required this.index,
    required super.position,
    required super.size,
    required this.maxHp,
  }) : hp = maxHp,
       super(anchor: Anchor.center, priority: 4);

  /// Position in the field, identical on every client for a given round.
  final int index;
  final double maxHp;
  double hp;
  double _flash = 0;

  /// Debris colour of the explosion when this goes down.
  Color get debris;

  @override
  void onLoad() {
    add(RectangleHitbox());
  }

  /// Applies [value] as the new health. Returns true when it got destroyed.
  bool setHp(double value) {
    if (value < hp) {
      _flash = 0.12;
    }
    hp = value.clamp(0.0, maxHp);
    if (hp <= 0 && isMounted) {
      parent?.add(Explosion(position: position.clone(), color: debris));
      parent?.add(Rubble(position: position.clone(), size: size.clone()));
      removeFromParent();
      return true;
    }
    return false;
  }

  @override
  void update(double dt) {
    if (_flash > 0) {
      _flash -= dt;
    }
  }

  double get damageRatio => 1 - hp / maxHp;

  Color tint(Color base) {
    var color = Color.lerp(base, const Color(0xFF000000), damageRatio * 0.35)!;
    if (_flash > 0) {
      color = Color.lerp(color, const Color(0xFFFFFFFF), 0.5)!;
    }
    return color;
  }

  void drawCracks(Canvas canvas) {
    final cracks = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xCC000000);
    final steps = (damageRatio * 5).floor();
    for (var i = 0; i < steps; i++) {
      final x = size.x * (0.2 + 0.18 * i);
      canvas.drawLine(
        Offset(x, size.y * 0.15),
        Offset(x + 8, size.y * 0.5),
        cracks,
      );
      canvas.drawLine(
        Offset(x + 8, size.y * 0.5),
        Offset(x - 4, size.y * 0.85),
        cracks,
      );
    }
  }
}

/// A house, seen from above. Pitched roofs on the training ground and in the
/// snow, flat roofs with rooftop boxes in the desert and the city.
class Building extends Obstacle {
  Building({
    required super.index,
    required super.position,
    required super.size,
    this.theme = MapTheme.forest,
  }) : super(maxHp: 90);

  final MapTheme theme;

  @override
  Color get debris => theme.debris;

  @override
  void render(Canvas canvas) {
    final rect = Offset.zero & Size(size.x, size.y);
    canvas.drawRect(
      rect.shift(const Offset(4, 5)),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawRect(rect, Paint()..color = tint(theme.wall));
    canvas.drawRect(rect.deflate(5), Paint()..color = tint(theme.roof));
    if (theme.flatRoofs) {
      _flatRoof(canvas);
    } else {
      _pitchedRoof(canvas);
    }
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = theme.wallEdge,
    );
    drawCracks(canvas);
  }

  void _pitchedRoof(Canvas canvas) {
    final ridge = Paint()
      ..strokeWidth = 2
      ..color = tint(theme.roofLine);
    if (size.x >= size.y) {
      canvas.drawLine(
        Offset(5, size.y / 2),
        Offset(size.x - 5, size.y / 2),
        ridge,
      );
      for (var x = 14.0; x < size.x - 6; x += 12) {
        canvas.drawLine(
          Offset(x, 5),
          Offset(x, size.y - 5),
          Paint()
            ..strokeWidth = 0.7
            ..color = tint(theme.roofLine),
        );
      }
    } else {
      canvas.drawLine(
        Offset(size.x / 2, 5),
        Offset(size.x / 2, size.y - 5),
        ridge,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(size.x * 0.68, size.y * 0.18, 9, 9),
      Paint()..color = tint(theme.window),
    );
  }

  void _flatRoof(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(10, 10, size.x - 20, size.y - 20),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = tint(theme.roofLine),
    );
    canvas.drawRect(
      Rect.fromLTWH(size.x * 0.18, size.y * 0.2, 14, 11),
      Paint()..color = tint(theme.roofLine),
    );
    canvas.drawRect(
      Rect.fromLTWH(size.x * 0.55, size.y * 0.55, 10, 10),
      Paint()..color = tint(theme.window),
    );
  }
}

/// Cheap to place, quick to destroy: concrete trap, sandbags or ice block.
class Barrier extends Obstacle {
  Barrier({
    required super.index,
    required super.position,
    required super.size,
    this.theme = MapTheme.forest,
  }) : super(maxHp: 45);

  final MapTheme theme;

  @override
  Color get debris => theme.barrierDebris;

  @override
  void render(Canvas canvas) {
    final rect = Offset.zero & Size(size.x, size.y);
    canvas.drawRect(
      rect.shift(const Offset(2, 3)),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawRect(rect, Paint()..color = tint(theme.barrierBody));
    final stripe = Paint()..color = tint(theme.barrierStripe);
    final long = size.x >= size.y;
    final count = (long ? size.x : size.y) ~/ 14;
    for (var i = 0; i < count; i++) {
      final o = 4.0 + i * 14;
      canvas.drawRect(
        long
            ? Rect.fromLTWH(o, 2, 6, size.y - 4)
            : Rect.fromLTWH(2, o, size.x - 4, 6),
        stripe,
      );
    }
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = theme.barrierEdge,
    );
    drawCracks(canvas);
  }
}

/// What a destroyed building or barrier leaves behind. Tanks drive over it.
class Rubble extends PositionComponent {
  Rubble({required super.position, required super.size})
    : super(anchor: Anchor.center, priority: 2);

  @override
  void render(Canvas canvas) {
    final dark = Paint()..color = const Color(0xFF2B261F);
    final mid = Paint()..color = const Color(0xFF5A4E40);
    canvas.drawOval(
      Rect.fromLTWH(-4, -4, size.x + 8, size.y + 8),
      Paint()..color = const Color(0x66000000),
    );
    for (var i = 0; i < 9; i++) {
      final x = size.x * ((i * 37) % 100) / 100;
      final y = size.y * ((i * 61) % 100) / 100;
      canvas.drawRect(
        Rect.fromLTWH(x - 4, y - 3, 8 + (i % 3) * 3, 6 + (i % 2) * 3),
        i.isEven ? dark : mid,
      );
    }
  }
}
