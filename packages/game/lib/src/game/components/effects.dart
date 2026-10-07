import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';

/// Churned up ground behind the tanks. One component paints all the marks, so
/// a busy arena costs a single draw loop.
class TrackLayer extends Component {
  TrackLayer() : super(priority: -15);

  static const _lifetime = 5.0;
  static const _capacity = 900;

  final _marks = <_Mark>[];

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

  void clear() => _marks.clear();

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
