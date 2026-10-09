import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../net/payloads/flag_payload.dart';
import '../flag_match.dart';
import '../game_config.dart';
import '../tank_game.dart';

/// The two bases of a capture the flag round: a sandbagged circle in the
/// colour of its side, flat on the ground under the tanks.
class FlagBases extends Component {
  FlagBases() : super(priority: -5);

  @override
  void render(Canvas canvas) {
    for (final team in const [1, 2]) {
      final base = FlagMatch.baseOf(team).toOffset();
      final color = GameConfig.teamColors[team];
      const r = GameConfig.flagBaseRadius;
      canvas.drawCircle(
        base,
        r,
        Paint()..color = color.withValues(alpha: 0.16),
      );
      canvas.drawCircle(
        base,
        r - 5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = const Color(0xFFB59B6B),
      );
      for (var i = 0; i < 18; i++) {
        final a = 2 * pi * i / 18;
        canvas.drawLine(
          base + Offset(cos(a), sin(a)) * (r - 10),
          base + Offset(cos(a), sin(a)) * r,
          Paint()
            ..strokeWidth = 1.5
            ..color = const Color(0xFF6E5A3A),
        );
      }
      canvas.drawCircle(
        base,
        r - 12,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.7),
      );
      // The socket the flag stands in.
      canvas.drawCircle(base, 7, Paint()..color = const Color(0xFF2E221A));
    }
  }
}

/// Both flags: on their pole at home, on the ground with a ring that shows
/// when it goes home by itself, or above the tank that carries it.
class FlagMarkers extends Component with HasGameRef<TankGame> {
  FlagMarkers() : super(priority: 30);

  double _time = 0;

  @override
  void update(double dt) => _time += dt;

  @override
  void render(Canvas canvas) {
    final match = gameRef.flagMatch;
    if (match == null) {
      return;
    }
    for (final flag in match.flags.values) {
      final color = GameConfig.teamColors[flag.team];
      switch (flag.spot) {
        case FlagSpot.home:
          _flag(canvas, flag.position.toOffset(), color, pole: 46, cloth: 1);
        case FlagSpot.dropped:
          final at = flag.position.toOffset();
          final left =
              1 - (flag.lying / GameConfig.flagReturnSeconds).clamp(0.0, 1.0);
          canvas.drawCircle(
            at,
            GameConfig.flagReach,
            Paint()..color = color.withValues(alpha: 0.12),
          );
          canvas.drawArc(
            Rect.fromCircle(center: at, radius: GameConfig.flagReach),
            -pi / 2,
            2 * pi * left,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = color,
          );
          _flag(canvas, at, color, pole: 30, cloth: 0.8);
        case FlagSpot.carried:
          final carrier = gameRef.tankById(flag.carrier!);
          final at = (carrier?.position ?? flag.position).toOffset();
          _flag(
            canvas,
            at + const Offset(10, -12),
            color,
            pole: 34,
            cloth: 0.8,
          );
      }
    }
  }

  /// A pole standing at [foot] with a cloth that flutters a little.
  void _flag(
    Canvas canvas,
    Offset foot,
    Color color, {
    required double pole,
    required double cloth,
  }) {
    final top = foot - Offset(0, pole);
    canvas.drawLine(
      foot + const Offset(2, 2),
      top + const Offset(2, 2),
      Paint()
        ..strokeWidth = 3
        ..color = const Color(0x55000000),
    );
    canvas.drawLine(
      foot,
      top,
      Paint()
        ..strokeWidth = 3
        ..color = const Color(0xFF2E221A),
    );
    final w = 28 * cloth;
    final h = 17 * cloth;
    final wave = sin(_time * 6) * 3 * cloth;
    final path = Path()
      ..moveTo(top.dx, top.dy)
      ..quadraticBezierTo(top.dx + w / 2, top.dy - wave, top.dx + w, top.dy)
      ..lineTo(top.dx + w, top.dy + h)
      ..quadraticBezierTo(top.dx + w / 2, top.dy + h - wave, top.dx, top.dy + h)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xAA000000),
    );
  }
}
