import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../game_config.dart';
import '../space_game.dart';
import '../special_weapon.dart';
import 'effects.dart';

/// A shell from the grenade launcher. It arcs over everything in its way and
/// goes off where it lands. Every client flies it from the launch message
/// alone, so all of them see it land on the same spot.
class Grenade extends PositionComponent with HasGameRef<SpaceGame> {
  Grenade({
    required this.grenadeId,
    required this.ownerId,
    required Vector2 from,
    required Vector2 to,
  }) : _from = from.clone(),
       _to = to.clone(),
       super(position: from.clone(), priority: 21);

  final String grenadeId;
  final String ownerId;
  final Vector2 _from;
  final Vector2 _to;
  double _t = 0;
  double _smokeTimer = 0;

  /// Height above the ground, peaking halfway.
  double get _height => sin(pi * _t) * 70;

  @override
  void update(double dt) {
    _t += dt / GameConfig.grenadeFlightSeconds;
    if (_t >= 1) {
      gameRef.detonate(
        ownerId: ownerId,
        blastId: grenadeId,
        at: _to,
        weapon: SpecialWeapon.grenades,
      );
      removeFromParent();
      return;
    }
    position
      ..setFrom(_from)
      ..lerp(_to, _t);
    _smokeTimer -= dt;
    if (_smokeTimer <= 0) {
      _smokeTimer = 0.05;
      parent?.add(
        puff(
          position: position - Vector2(0, _height),
          color: const Color(0xFF9E9E96),
          count: 2,
          lifespan: 0.5,
          speed: (2, 10),
          size: (2, 4),
          opacity: 0.45,
          priority: 20,
        ),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    final height = _height;
    // Shadow on the ground, smaller and fainter the higher the shell flies.
    canvas.drawCircle(
      Offset.zero,
      4 - height / 40,
      Paint()..color = Color.fromRGBO(0, 0, 0, 0.35 - height / 400),
    );
    final scale = 1 + height / 90;
    canvas.drawCircle(
      Offset(0, -height),
      4.5 * scale,
      Paint()..color = const Color(0xFF2F3326),
    );
    canvas.drawCircle(
      Offset(-1.2 * scale, -height - 1.2 * scale),
      1.6 * scale,
      Paint()..color = const Color(0xFF8A9A5B),
    );
  }
}

/// Where a grenade is about to come down: a ring that tightens until impact.
class GrenadeMarker extends PositionComponent {
  GrenadeMarker({required super.position}) : super(priority: -5);

  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= GameConfig.grenadeFlightSeconds) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / GameConfig.grenadeFlightSeconds).clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset.zero,
      GameConfig.grenadeRadius * (1.15 - 0.15 * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Color.fromRGBO(239, 83, 80, 0.3 + 0.5 * t),
    );
  }
}
