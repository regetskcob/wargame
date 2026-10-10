import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../game/components/tank_base.dart';
import '../../game/game_phase.dart';
import '../../game/tank_game.dart';
import '../../game/game_config.dart';
import '../theme.dart';

/// Arrows on the edge of the view that point at enemy tanks which are off
/// screen, with the distance next to each.
///
/// Remote tanks move in steps of the 10 Hz network state and the camera
/// shakes, so following every frame made the arrows twitch. Targets are
/// therefore sampled a few times a second and the arrows glide towards
/// them; they fade in and out instead of popping.
class EnemyIndicators extends StatefulWidget {
  const EnemyIndicators({required this.game, super.key});

  final TankGame game;

  @override
  State<EnemyIndicators> createState() => _EnemyIndicatorsState();
}

/// How often the targets are looked up, in seconds.
const _samplePeriod = 0.25;

/// How fast an arrow closes in on its target angle, per second.
const _follow = 7.0;

/// How fast an arrow fades in or out, in full alpha per second.
const _fade = 5.0;

/// The distance shown next to an arrow: metres in steps of five, so the
/// label changes rarely and is easy to read in passing.
@visibleForTesting
int indicatorMetres(double distance) => ((distance / 10) / 5).round() * 5;

/// Moves [from] towards [to] by [t] (0..1) along the shorter way round.
@visibleForTesting
double approachAngle(double from, double to, double t) {
  var delta = (to - from) % (2 * pi);
  if (delta > pi) {
    delta -= 2 * pi;
  }
  return from + delta * t;
}

class _Marker {
  _Marker({required this.flag, required this.angle});

  final bool flag;
  double angle;
  double target = 0;
  double alpha = 0;
  bool wanted = true;
  int metres = 0;
  bool near = false;
  Color color = GameColors.danger;
}

class _EnemyIndicatorsState extends State<EnemyIndicators>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick)..start();
  final _markers = <String, _Marker>{};
  Duration _last = Duration.zero;
  double _sinceSample = _samplePeriod;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = elapsed;
    final size = context.size;
    final game = widget.game;
    final me = game.myTank;
    if (game.phase.value != GamePhase.playing || me == null || size == null) {
      if (_markers.isNotEmpty) {
        setState(_markers.clear);
      }
      _sinceSample = _samplePeriod;
      return;
    }
    _sinceSample += dt;
    if (_sinceSample >= _samplePeriod) {
      _sinceSample = 0;
      _sample(me, size);
    }
    final follow = 1 - exp(-_follow * dt);
    _markers.removeWhere((_, marker) {
      marker.angle = approachAngle(marker.angle, marker.target, follow);
      marker.alpha = marker.wanted
          ? min(1, marker.alpha + _fade * dt)
          : max(0, marker.alpha - _fade * dt);
      return !marker.wanted && marker.alpha == 0;
    });
    setState(() {});
  }

  /// Looks up which enemies and flags lie beyond the edge and where.
  void _sample(TankBase me, Size size) {
    final game = widget.game;
    final scale = game.viewScale;
    final camera = game.camera.viewfinder.position;
    final halfWidth = size.width / 2 - 30;
    final halfHeight = size.height / 2 - 30;
    for (final marker in _markers.values) {
      marker.wanted = false;
    }

    /// The angle from the middle of the view, or null when on screen.
    double? beyond(double x, double y) {
      final dx = (x - camera.x) * scale;
      final dy = (y - camera.y) * scale;
      if (dx.abs() <= halfWidth && dy.abs() <= halfHeight) {
        return null;
      }
      return atan2(dy, dx);
    }

    _Marker show(String key, double angle, {required bool flag}) {
      final marker = _markers.putIfAbsent(
        key,
        () => _Marker(flag: flag, angle: angle),
      );
      marker
        ..target = angle
        ..wanted = true;
      return marker;
    }

    // Capture the flag: where both flags are, beyond the edge.
    final flags = game.flagMatch;
    if (flags != null) {
      for (final flag in flags.flags.values) {
        final carrier = flag.carrier;
        if (carrier == me.playerId) {
          continue;
        }
        final at = carrier == null
            ? flag.position
            : game.tankById(carrier)?.position ?? flag.position;
        final angle = beyond(at.x, at.y);
        if (angle != null) {
          show('flag-${flag.team}', angle, flag: true).color =
              GameConfig.teamColors[flag.team];
        }
      }
    }

    final enemies =
        <TankBase>[...game.remoteTanks.values, ...game.botTanks.values]
            .where(
              (tank) =>
                  tank.isMounted &&
                  !tank.hidden &&
                  game.canSee(tank.position) &&
                  !game.sameTeam(me.playerId, tank.playerId),
            )
            .toList()
          ..sort(
            (a, b) => a.position
                .distanceTo(me.position)
                .compareTo(b.position.distanceTo(me.position)),
          );
    for (final tank in enemies.take(6)) {
      final angle = beyond(tank.position.x, tank.position.y);
      if (angle == null) {
        continue;
      }
      final distance = tank.position.distanceTo(me.position);
      show('tank-${tank.playerId}', angle, flag: false)
        ..metres = indicatorMetres(distance)
        ..near = distance < 450
        ..color = tank.team > 0
            ? GameConfig.teamColors[tank.team]
            : GameColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: CustomPaint(painter: _IndicatorPainter(_markers.values)),
      ),
    );
  }
}

class _IndicatorPainter extends CustomPainter {
  _IndicatorPainter(this.markers);

  final Iterable<_Marker> markers;

  @override
  void paint(Canvas canvas, Size size) {
    final inner = (Offset.zero & size).deflate(30);
    final centre = inner.center;
    for (final marker in markers) {
      // The arrow sits where its direction leaves the inner frame, so it
      // slides along the edge and round the corners as the angle turns.
      final direction = Offset(cos(marker.angle), sin(marker.angle));
      final tx = direction.dx == 0
          ? double.infinity
          : (inner.width / 2) / direction.dx.abs();
      final ty = direction.dy == 0
          ? double.infinity
          : (inner.height / 2) / direction.dy.abs();
      final reach = min(tx, ty);
      if (marker.flag) {
        _flagMarker(
          canvas,
          centre + direction * reach * 0.9,
          marker.color,
          marker.alpha,
        );
      } else {
        _arrow(canvas, centre + direction * reach, marker);
      }
    }
  }

  void _arrow(Canvas canvas, Offset at, _Marker marker) {
    final alpha = marker.alpha;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(marker.angle);
    final arrow = Path()
      ..moveTo(16, 0)
      ..lineTo(-9, -11)
      ..lineTo(-4, 0)
      ..lineTo(-9, 11)
      ..close();
    canvas.drawPath(
      arrow,
      Paint()..color = Color.fromRGBO(0, 0, 0, 0.53 * alpha),
    );
    canvas.drawPath(
      arrow.shift(const Offset(-1, 0)),
      Paint()
        ..color = marker.color.withValues(
          alpha: (marker.near ? 1 : 0.75) * alpha,
        ),
    );
    canvas.restore();

    final label = TextPainter(
      text: TextSpan(
        text: '${marker.metres} m',
        style: TextStyle(
          color: marker.color.withValues(alpha: alpha),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          shadows: [
            Shadow(blurRadius: 3, color: Colors.black.withValues(alpha: alpha)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // The label sits on the side of the arrow that faces the middle.
    final inward = Offset(-cos(marker.angle), -sin(marker.angle)) * 26;
    label.paint(
      canvas,
      at + inward - Offset(label.width / 2, label.height / 2),
    );
  }

  /// A small flag on the edge of the view, where a flag lies beyond it.
  void _flagMarker(Canvas canvas, Offset at, Color color, double alpha) {
    canvas.drawCircle(
      at,
      13,
      Paint()..color = Color.fromRGBO(0, 0, 0, 0.6 * alpha),
    );
    canvas.drawLine(
      at + const Offset(-4, 8),
      at + const Offset(-4, -8),
      Paint()
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: alpha),
    );
    canvas.drawPath(
      Path()
        ..moveTo(at.dx - 4, at.dy - 8)
        ..lineTo(at.dx + 8, at.dy - 4)
        ..lineTo(at.dx - 4, at.dy)
        ..close(),
      Paint()..color = color.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(_IndicatorPainter old) => true;
}
