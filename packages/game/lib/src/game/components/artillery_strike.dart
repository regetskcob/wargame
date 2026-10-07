import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../game_config.dart';
import '../space_game.dart';
import 'effects.dart';
import 'explosion.dart';

/// A barrage on its way: a pulsing target circle that everybody sees, then a
/// handful of shells that strike inside it. The damage lands once, at [at],
/// on every client for the tanks that client runs.
class ArtilleryStrike extends PositionComponent with HasGameRef<SpaceGame> {
  ArtilleryStrike({
    required this.strikeId,
    required this.ownerId,
    required this.at,
    required super.position,
  }) : super(priority: 2);

  final String strikeId;
  final String ownerId;

  /// Bombs of a jet (`-b0`) or of the bomber from a gem (`-j3`), not shells
  /// of an artillery crate (`-a3`).
  bool get fromJet => _bomb.hasMatch(strikeId);
  static final _bomb = RegExp(r'-[bj]\d+$');

  double get damage =>
      fromJet ? GameConfig.bombDamage : GameConfig.artilleryDamage;

  /// Impact time, milliseconds since the epoch.
  final int at;

  static const _shells = 6;
  final _random = Random();
  var _landed = false;
  var _shellsFired = 0;
  double _age = 0;

  double get _secondsToImpact =>
      (at - DateTime.now().millisecondsSinceEpoch) / 1000;

  @override
  void update(double dt) {
    _age += dt;
    final left = _secondsToImpact;
    // Shells come down over a short spell around the impact time.
    final due = ((-left + 0.3) / 0.6 * _shells).floor().clamp(0, _shells);
    while (_shellsFired < due) {
      _shellsFired++;
      final spread = Vector2(
        _random.nextDouble() * 2 - 1,
        _random.nextDouble() * 2 - 1,
      )..scale(GameConfig.artilleryRadius * 0.7);
      final point = position + spread;
      parent?.add(Explosion(position: point, color: const Color(0xFF6B5A3A)));
      gameRef.addCrater(point, 14 + _random.nextDouble() * 8);
      gameRef.shakeAt(point, 5);
    }
    if (!_landed && left <= 0) {
      _landed = true;
      gameRef.artilleryImpact(this);
    }
    if (left < -1.2) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final left = _secondsToImpact;
    if (left <= 0) {
      return;
    }
    final radius = GameConfig.artilleryRadius;
    final pulse = 0.5 + 0.5 * sin(_age * (10 - 2.5 * left.clamp(0, 3)));
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()..color = Color.fromRGBO(255, 87, 34, 0.1 + 0.12 * pulse),
    );
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Color.fromRGBO(255, 87, 34, 0.55 + 0.4 * pulse),
    );
    // Closing ring that reaches the target circle at impact.
    final share = (left / GameConfig.artilleryDelay).clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset.zero,
      radius * (1 + share),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0x99FF5722),
    );
    final cross = Paint()
      ..strokeWidth = 2
      ..color = const Color(0xCCFF5722);
    canvas.drawLine(const Offset(-14, 0), const Offset(14, 0), cross);
    canvas.drawLine(const Offset(0, -14), const Offset(0, 14), cross);
  }
}

/// Blast, smoke and a crater where a mine went off.
void mineBlast(SpaceGame game, Vector2 at) {
  game.addCrater(at, 12);
  final parent = game.world;
  parent.addAll([
    Explosion(position: at, color: const Color(0xFF3A3A30)),
    puff(
      position: at,
      color: const Color(0xFF5A4A30),
      count: 8,
      lifespan: 1.2,
      speed: (10, 50),
      size: (5, 12),
      opacity: 0.6,
    ),
  ]);
}
