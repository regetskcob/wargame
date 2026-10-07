import 'dart:math';
import 'dart:ui';

import 'map_theme.dart';

/// What falls from the sky. Rain, snow or sand depends on the ground: snow
/// in winter, sand in the desert, rain everywhere else.
enum Sky { clear, precipitation, fog }

/// Weather and time of day of a round. Like the map they follow from the
/// round seed alone, so every client sees the same sky for free.
///
/// The seed carries them in fixed places: the map in `seed % 4`, the sky in
/// the next factor of 20 and the time of day in the next factor of 4.
class Conditions {
  const Conditions({
    required this.sky,
    required this.night,
    required this.theme,
  });

  factory Conditions.forSeed(int seed) {
    final skyBucket = (seed ~/ _mapFactor) % _skyFactor;
    final nightBucket = (seed ~/ (_mapFactor * _skyFactor)) % _nightFactor;
    return Conditions(
      sky: _skyOf(skyBucket),
      night: nightBucket == 0,
      theme: MapTheme.forSeed(seed),
    );
  }

  final Sky sky;
  final bool night;
  final MapTheme theme;

  static const _mapFactor = 4;
  static const _skyFactor = 20;
  static const _nightFactor = 4;

  /// 11 of 20 rounds are clear, 5 have rain, snow or sand, 4 fog.
  static Sky _skyOf(int bucket) => bucket < 11
      ? Sky.clear
      : bucket < 16
      ? Sky.precipitation
      : Sky.fog;

  static const _skyBuckets = {Sky.clear: 0, Sky.precipitation: 11, Sky.fog: 16};

  /// Rewrites [seed] so that it brings [sky] and [night] where given and
  /// keeps everything else, the map included.
  static int seedWith(int seed, {Sky? sky, bool? night}) {
    final map = seed % _mapFactor;
    var skyBucket = (seed ~/ _mapFactor) % _skyFactor;
    var nightBucket = (seed ~/ (_mapFactor * _skyFactor)) % _nightFactor;
    final rest = seed ~/ (_mapFactor * _skyFactor * _nightFactor);
    if (sky != null && _skyOf(skyBucket) != sky) {
      skyBucket = _skyBuckets[sky]!;
    }
    if (night != null && (nightBucket == 0) != night) {
      nightBucket = night ? 0 : 1;
    }
    return ((rest * _nightFactor + nightBucket) * _skyFactor + skyBucket) *
            _mapFactor +
        map;
  }

  bool get snow => sky == Sky.precipitation && theme == MapTheme.winter;
  bool get sand => sky == Sky.precipitation && theme == MapTheme.desert;
  bool get rain => sky == Sky.precipitation && !snow && !sand;

  /// How far a tank can see, in world units. Null means as far as the screen.
  double? get vision {
    final weather = switch (sky) {
      Sky.fog => 380.0,
      Sky.precipitation when sand => 440.0,
      _ => null,
    };
    if (!night) {
      return weather;
    }
    return min(weather ?? double.infinity, 340.0) * (weather == null ? 1 : 0.8);
  }

  String get label {
    final weather = switch (sky) {
      Sky.clear => night ? 'Sternklar' : 'Klar',
      Sky.fog => 'Nebel',
      Sky.precipitation when snow => 'Schneefall',
      Sky.precipitation when sand => 'Sandsturm',
      Sky.precipitation => 'Regen',
    };
    return night ? 'Nacht, $weather' : weather;
  }
}

/// Paints the weather on top of the world in screen space: darkness with a
/// circle of sight and headlights at night, a veil of fog or sand, and rain,
/// snow or sand that drifts with the ground as the camera moves.
class WeatherLayer {
  WeatherLayer(this.conditions) {
    final random = Random(7);
    final count = conditions.sky == Sky.precipitation
        ? (conditions.snow ? 140 : 220)
        : 0;
    _particles = [
      for (var i = 0; i < count; i++)
        _Particle(
          random.nextDouble(),
          random.nextDouble(),
          random.nextDouble(),
        ),
    ];
  }

  final Conditions conditions;
  late final List<_Particle> _particles;
  double _time = 0;

  void update(double dt) {
    _time += dt;
  }

  /// [camera] is the world point in the middle of the screen, [scale] the
  /// pixels per world unit, [heading] the hull angle of the player's tank for
  /// the headlights, null without a tank.
  void render(
    Canvas canvas,
    Size size, {
    required Offset camera,
    required double scale,
    double? heading,
    bool veil = true,
  }) {
    _precipitation(canvas, size, camera, scale);
    if (veil) {
      _veil(canvas, size, scale, heading);
    }
  }

  void _precipitation(Canvas canvas, Size size, Offset camera, double scale) {
    if (_particles.isEmpty) {
      return;
    }
    if (conditions.rain) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0x22101828),
      );
    }
    // The particles live on a tile the size of the view that repeats over
    // the world, so they slide past as the tank drives.
    final tileW = size.width / scale;
    final tileH = size.height / scale;
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (final p in _particles) {
      double wrap(double v, double m) => ((v % m) + m) % m;
      final double fallX;
      final double fallY;
      if (conditions.snow) {
        fallX = sin(_time * 0.8 + p.seed * 20) * 18 + _time * 12;
        fallY = _time * (35 + 25 * p.seed);
      } else if (conditions.sand) {
        fallX = _time * (260 + 140 * p.seed);
        fallY = sin(_time * 2 + p.seed * 30) * 14;
      } else {
        fallX = _time * 90;
        fallY = _time * (520 + 200 * p.seed);
      }
      final wx = wrap(p.x * tileW + fallX - camera.dx, tileW);
      final wy = wrap(p.y * tileH + fallY - camera.dy, tileH);
      final at = Offset(wx * scale, wy * scale);
      if (conditions.snow) {
        paint.color = Color.fromRGBO(255, 255, 255, 0.55 + 0.4 * p.seed);
        canvas.drawCircle(at, (1.2 + 1.8 * p.seed) * scale, paint);
      } else if (conditions.sand) {
        paint
          ..color = Color.fromRGBO(222, 190, 130, 0.35 + 0.3 * p.seed)
          ..strokeWidth = 1.4 * scale;
        canvas.drawLine(at, at + Offset(-14 * scale, 0), paint);
      } else {
        paint
          ..color = Color.fromRGBO(180, 200, 230, 0.25 + 0.3 * p.seed)
          ..strokeWidth = 1.1 * scale;
        canvas.drawLine(at, at + Offset(-2.5 * scale, -16 * scale), paint);
      }
    }
  }

  void _veil(Canvas canvas, Size size, double scale, double? heading) {
    final vision = conditions.vision;
    if (vision == null) {
      return;
    }
    final Color shade;
    if (conditions.night) {
      shade = const Color(0xE6040814);
    } else if (conditions.sand) {
      shade = const Color(0xC8B9935A);
    } else {
      shade = const Color(0xD8B4BAC0);
    }
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = vision * scale;
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, Paint()..color = shade);
    final clear = Paint()
      ..blendMode = BlendMode.dstOut
      ..shader = Gradient.radial(
        centre,
        radius,
        const [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        const [0, 0.55, 1],
      );
    canvas.drawCircle(centre, radius, clear);
    if (conditions.night && heading != null) {
      // Two headlight beams that reach further than the circle of sight.
      final reach = radius * 1.7;
      final forward = Offset(sin(heading), -cos(heading));
      final cone = Path()..moveTo(centre.dx, centre.dy);
      for (var i = -6; i <= 6; i++) {
        final a = heading + i * 0.055;
        cone.lineTo(centre.dx + sin(a) * reach, centre.dy - cos(a) * reach);
      }
      cone.close();
      canvas.drawPath(
        cone,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..shader = Gradient.linear(centre, centre + forward * reach, const [
            Color(0xDDFFFFFF),
            Color(0x00FFFFFF),
          ]),
      );
    }
    canvas.restore();
    if (conditions.night) {
      // A faint blue cast over what is lit.
      canvas.drawRect(rect, Paint()..color = const Color(0x1A1A2A55));
    }
  }
}

class _Particle {
  _Particle(this.x, this.y, this.seed);

  final double x;
  final double y;
  final double seed;
}
