import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';

import 'effects.dart';

/// A tank blowing up: a bright flash with a shock ring, a fireball, flying
/// sparks and a column of dark smoke.
class Explosion extends PositionComponent {
  Explosion({required Vector2 position, required this.color})
    : super(position: position, priority: 15);

  final Color color;

  static const _lifetime = 0.5;
  double _age = 0;

  @override
  void onLoad() {
    addAll([
      _emitter(
        count: 18,
        lifespan: 0.7,
        speed: (20, 110),
        size: (8, 16),
        color: const Color(0xFFFF8A1F),
      ),
      _emitter(
        count: 14,
        lifespan: 0.9,
        speed: (40, 190),
        size: (3, 6),
        color: const Color(0xFFFFE08A),
      ),
      _emitter(
        count: 10,
        lifespan: 0.9,
        speed: (30, 160),
        size: (3, 6),
        color: color,
      ),
      puff(
        position: Vector2.zero(),
        color: const Color(0xFF2B2824),
        count: 12,
        lifespan: 1.8,
        speed: (8, 42),
        size: (10, 22),
        opacity: 0.6,
        priority: 14,
      ),
    ]);
  }

  ParticleEmitterComponent _emitter({
    required int count,
    required double lifespan,
    required (double, double) speed,
    required (double, double) size,
    required Color color,
  }) {
    return ParticleEmitterComponent(
      emitter: ParticleEmitter(
        maxParticles: count,
        bursts: [EmitterBurst(0, count)],
        lifespan: (lifespan, lifespan),
        speed: speed,
        size: size,
        opacityOverLife: ParticleCurve(1, 0),
        colorOverLife: ColorRamp.solid(color),
      ),
      renderer: CircleParticleRenderer(),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age > 2) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_age >= _lifetime) {
      return;
    }
    final t = _age / _lifetime;
    canvas.drawCircle(
      Offset.zero,
      20 + 50 * t,
      Paint()..color = Color.fromRGBO(255, 214, 120, 0.7 * (1 - t)),
    );
    canvas.drawCircle(
      Offset.zero,
      16 + 110 * t,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - t) + 0.5
        ..color = Color.fromRGBO(255, 255, 255, 0.55 * (1 - t)),
    );
  }
}
