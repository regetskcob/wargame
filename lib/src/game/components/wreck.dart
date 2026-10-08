import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';

import 'tank_painter.dart';

/// What is left of a destroyed tank: a charred hull that keeps smoking.
class Wreck extends PositionComponent {
  Wreck({
    required super.position,
    required super.angle,
    required this.tankType,
    required double hullSize,
  }) : super(size: Vector2.all(hullSize), anchor: Anchor.center, priority: 6);

  final TankType tankType;
  final _random = Random();
  double _puff = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _puff -= dt;
    if (_puff <= 0 && isMounted) {
      _puff = 0.35 + _random.nextDouble() * 0.2;
      parent?.add(
        ParticleEmitterComponent(
          position:
              position +
              Vector2(
                _random.nextDouble() * 14 - 7,
                _random.nextDouble() * 14 - 7,
              ),
          priority: 16,
          emitter: ParticleEmitter(
            maxParticles: 3,
            bursts: const [EmitterBurst(0, 3)],
            lifespan: (1.6, 1.6),
            speed: (8, 22),
            size: (7, 12),
            opacityOverLife: ParticleCurve(0.55, 0),
            colorOverLife: ColorRamp.solid(const Color(0xFF3A3A3A)),
          ),
          renderer: CircleParticleRenderer(),
        ),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    paintTank(
      canvas,
      size.x,
      tankType,
      const Color(0xFF2B2B28),
      deck: const Color(0xFF363632),
    );
    canvas.drawCircle(
      Offset(size.x * 0.5, size.y * 0.55),
      size.x * 0.12,
      Paint()..color = const Color(0xAAFF6F00),
    );
  }
}

/// A salute for the winner: gold and white bursts around the surviving tank.
class Fireworks extends Component {
  Fireworks({required this.centre});

  final Vector2 Function() centre;
  final _random = Random();
  double _elapsed = 0;
  double _next = 0;

  static const _colors = [
    Color(0xFFFFD54F),
    Color(0xFFFFFFFF),
    Color(0xFFFFB300),
    Color(0xFF9CCC65),
  ];

  @override
  void update(double dt) {
    _elapsed += dt;
    _next -= dt;
    if (_elapsed > 5) {
      removeFromParent();
      return;
    }
    if (_next <= 0) {
      _next = 0.18;
      final angle = _random.nextDouble() * 2 * pi;
      final distance = 30 + _random.nextDouble() * 90;
      parent?.add(
        ParticleEmitterComponent(
          position: centre() + Vector2(cos(angle), sin(angle)) * distance,
          priority: 20,
          emitter: ParticleEmitter(
            maxParticles: 30,
            bursts: const [EmitterBurst(0, 30)],
            lifespan: (1.1, 1.1),
            speed: (50, 150),
            size: (2, 4),
            opacityOverLife: ParticleCurve(1, 0),
            colorOverLife: ColorRamp.solid(
              _colors[_random.nextInt(_colors.length)],
            ),
          ),
          renderer: CircleParticleRenderer(),
        ),
      );
    }
  }
}
