import 'dart:math';
import 'dart:ui' hide TextStyle;

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/painting.dart' show FontWeight, Shadow, TextStyle;

/// Churned up ground behind the tanks. One component paints all the marks, so
/// a busy arena costs a single draw loop.
class TrackLayer extends Component {
  TrackLayer() : super(priority: -15);

  static const _lifetime = 5.0;
  static const _capacity = 900;

  final _marks = <_Mark>[];

  /// Scorched holes from mines and barrages, kept for the whole round.
  final _craters = <(double, double, double)>[];

  void addCrater(Vector2 at, double radius) {
    _craters.add((at.x, at.y, radius));
  }

  void addMarks(
    Vector2 left,
    Vector2 right,
    double angle, {
    bool bloody = false,
  }) {
    _marks
      ..add(_Mark(left.x, left.y, angle, bloody))
      ..add(_Mark(right.x, right.y, angle, bloody));
    if (_marks.length > _capacity) {
      _marks.removeRange(0, _marks.length - _capacity);
    }
  }

  void clear() {
    _marks.clear();
    _craters.clear();
  }

  @override
  void update(double dt) {
    for (final mark in _marks) {
      mark.age += dt;
    }
    _marks.removeWhere((mark) => mark.age > _lifetime);
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint();
    for (final (x, y, radius) in _craters) {
      paint.color = const Color(0x55241A10);
      canvas.drawCircle(Offset(x, y), radius * 1.25, paint);
      paint.color = const Color(0x99140E08);
      canvas.drawCircle(Offset(x, y), radius * 0.8, paint);
      paint.color = const Color(0x55000000);
      canvas.drawCircle(
        Offset(x + radius * 0.15, y + radius * 0.1),
        radius * 0.45,
        paint,
      );
    }
    for (final mark in _marks) {
      final fade = 1 - mark.age / _lifetime;
      paint.color = mark.bloody
          ? Color.fromRGBO(120, 14, 14, 0.6 * fade)
          : Color.fromRGBO(30, 24, 14, 0.38 * fade);
      canvas.save();
      canvas.translate(mark.x, mark.y);
      canvas.rotate(mark.angle);
      canvas.drawRect(const Rect.fromLTWH(-2.6, -2, 5.2, 4), paint);
      canvas.restore();
    }
  }
}

class _Mark {
  _Mark(this.x, this.y, this.angle, this.bloody);

  final double x;
  final double y;
  final double angle;
  final bool bloody;
  double age = 0;
}

final _random = Random();

/// A short lived puff of [count] soft particles.
ParticleEmitterComponent puff({
  required Vector2 position,
  required Color color,
  int count = 4,
  double lifespan = 1.0,
  (double, double) speed = (6, 24),
  (double, double) size = (4, 9),
  double opacity = 0.5,
  int priority = 16,
}) {
  return ParticleEmitterComponent(
    position: position,
    priority: priority,
    emitter: ParticleEmitter(
      maxParticles: count,
      bursts: [EmitterBurst(0, count)],
      lifespan: (lifespan, lifespan),
      speed: speed,
      size: size,
      opacityOverLife: ParticleCurve(opacity, 0),
      colorOverLife: ColorRamp.solid(color),
    ),
    renderer: CircleParticleRenderer(),
  );
}

Vector2 jitter(Vector2 base, double amount) =>
    base +
    Vector2(
      (_random.nextDouble() * 2 - 1) * amount,
      (_random.nextDouble() * 2 - 1) * amount,
    );

/// A number that rises from a hit tank and fades out. [mine] marks a hit the
/// local player dealt or took, and is drawn bigger.
class DamageNumber extends PositionComponent {
  DamageNumber({
    required Vector2 position,
    required double amount,
    required Color color,
    bool mine = false,
  }) : _mine = mine,
       _paint = TextPaint(
         style: TextStyle(
           color: color,
           fontSize: mine ? 17 : 12,
           fontWeight: FontWeight.w900,
           shadows: const [Shadow(blurRadius: 3, color: Color(0xFF000000))],
         ),
       ),
       _text = amount.round().clamp(1, 999).toString(),
       super(
         position: jitter(position, 10),
         priority: 30,
         anchor: Anchor.center,
       );

  final bool _mine;
  final TextPaint _paint;
  final String _text;
  static const _lifetime = 0.9;
  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    position.y -= 38 * dt;
    if (_age >= _lifetime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final fade = (1 - _age / _lifetime).clamp(0.0, 1.0);
    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(255, 255, 255, fade),
    );
    if (_mine) {
      // Hit marker: four short strokes around the number.
      final marker = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..strokeWidth = 2;
      final spread = 14 + 8 * (_age / _lifetime);
      for (final d in const [
        (-1.0, -1.0),
        (1.0, -1.0),
        (-1.0, 1.0),
        (1.0, 1.0),
      ]) {
        canvas.drawLine(
          Offset(d.$1 * spread, d.$2 * spread),
          Offset(d.$1 * (spread - 5), d.$2 * (spread - 5)),
          marker,
        );
      }
    }
    _paint.render(canvas, _text, Vector2.zero(), anchor: Anchor.center);
    canvas.restore();
  }
}

/// The name of a crate or gem a CPU tank sets off, rising from it, so
/// players see what the bots do with what they pick up.
class ItemCallout extends PositionComponent {
  ItemCallout({
    required Vector2 position,
    required this.text,
    required Color color,
  }) : _paint = TextPaint(
         style: TextStyle(
           color: color,
           fontSize: 13,
           fontWeight: FontWeight.w900,
           letterSpacing: 1,
           shadows: const [Shadow(blurRadius: 4, color: Color(0xFF000000))],
         ),
       ),
       super(position: position, priority: 30, anchor: Anchor.center);

  final String text;
  final TextPaint _paint;
  static const _lifetime = 1.6;
  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    position.y -= 22 * dt;
    if (_age >= _lifetime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final fade = (1 - _age / _lifetime).clamp(0.0, 1.0);
    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(255, 255, 255, fade),
    );
    _paint.render(canvas, text, Vector2.zero(), anchor: Anchor.center);
    canvas.restore();
  }
}

/// A red cross over a tank the local player just destroyed.
class KillMarker extends PositionComponent {
  KillMarker({required Vector2 position})
    : super(position: position, priority: 31, anchor: Anchor.center);

  static const _lifetime = 1.1;
  static final _label = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFF5A45),
      fontSize: 14,
      fontWeight: FontWeight.w900,
      letterSpacing: 2,
      shadows: [Shadow(blurRadius: 3, color: Color(0xFF000000))],
    ),
  );
  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= _lifetime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = _age / _lifetime;
    final fade = (1 - t).clamp(0.0, 1.0);
    // Pops in big and settles.
    final arm = 30 * (1 + 0.6 * (1 - (t * 5).clamp(0.0, 1.0)));
    final paint = Paint()
      ..color = Color.fromRGBO(255, 90, 69, fade)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-arm, -arm), Offset(arm, arm), paint);
    canvas.drawLine(Offset(arm, -arm), Offset(-arm, arm), paint);
    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(255, 255, 255, fade),
    );
    _label.render(
      canvas,
      'ABSCHUSS',
      Vector2(0, -arm - 12),
      anchor: Anchor.bottomCenter,
    );
    canvas.restore();
  }
}
