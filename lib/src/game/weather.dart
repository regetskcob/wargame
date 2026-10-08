import 'dart:math';
import 'dart:ui';

import 'map_theme.dart';
import '../l10n/l10n.dart';

/// What falls from the sky. Rain, snow or sand depends on the ground: snow
/// in winter, sand in the desert, rain everywhere else.
enum Sky { clear, precipitation, fog }

/// Weather and time of day of a round. Like the map they follow from the
/// round seed and the round clock alone, so every client sees the same sky
/// for free.
///
/// The seed carries the map in `seed % 4` and the opening sky in the next
/// factor of 20. Day and night take turns at a fixed pace, the seed only
/// says where in that turn a round begins.
class Conditions {
  const Conditions({
    required this.sky,
    required this.night,
    required this.theme,
  });

  factory Conditions.forSeed(int seed) {
    final skyBucket = (seed ~/ _mapFactor) % _skyFactor;
    return Conditions(
      sky: _skyOf(skyBucket),
      night: nightAt(seed, 0),
      theme: MapTheme.forSeed(seed),
    );
  }

  final Sky sky;
  final bool night;
  final MapTheme theme;

  /// How long one spell of weather lasts at least, in seconds.
  static const spell = 70.0;

  /// Length of the day and of the night, in seconds. One whole turn fits
  /// into a usual round, so most rounds see the light change.
  static const dayLength = 80.0;
  static const nightLength = 40.0;
  static const _cycle = dayLength + nightLength;

  /// Whether it is night [seconds] into a round with [seed].
  static bool nightAt(int seed, double seconds) {
    final offset = Random(seed * 13 + 101).nextDouble() * _cycle;
    return (offset + max(0, seconds)) % _cycle >= dayLength;
  }

  /// The weather [seconds] into a round with [seed]. It starts with the sky
  /// of the seed and may turn after every [spell]: half the time it stays,
  /// otherwise it rolls anew. Every client works out the same sky from the
  /// seed and the round clock alone.
  static Sky skyAt(int seed, double seconds) {
    var sky = Conditions.forSeed(seed).sky;
    final spells = max(0, seconds ~/ spell);
    for (var k = 1; k <= spells; k++) {
      final random = Random(seed * 31 + k * 7919);
      if (random.nextBool()) {
        sky = _skyOf(random.nextInt(_skyFactor));
      }
    }
    return sky;
  }

  /// Sky and time of day [seconds] into a round with [seed].
  static Conditions at(int seed, double seconds, MapTheme theme) => Conditions(
    sky: skyAt(seed, seconds),
    night: nightAt(seed, seconds),
    theme: theme,
  );

  static const _mapFactor = 4;
  static const _skyFactor = 20;

  /// 11 of 20 rounds are clear, 5 have rain, snow or sand, 4 fog.
  static Sky _skyOf(int bucket) => bucket < 11
      ? Sky.clear
      : bucket < 16
      ? Sky.precipitation
      : Sky.fog;

  bool get snow => sky == Sky.precipitation && theme == MapTheme.winter;
  bool get sand => sky == Sky.precipitation && theme == MapTheme.desert;
  bool get rain => sky == Sky.precipitation && !snow && !sand;

  /// How far a tank can see, in world units. Null means as far as the screen.
  double? get vision {
    final weather = switch (sky) {
      Sky.fog => 460.0,
      Sky.precipitation when sand => 500.0,
      _ => null,
    };
    if (!night) {
      return weather;
    }
    return min(weather ?? double.infinity, 340.0) * (weather == null ? 1 : 0.8);
  }

  String get label {
    final weather = switch (sky) {
      Sky.clear => night ? tr('Sternklar', 'Starry') : tr('Klar', 'Clear'),
      Sky.fog => tr('Nebel', 'Fog'),
      Sky.precipitation when snow => tr('Schneefall', 'Snowfall'),
      Sky.precipitation when sand => tr('Sandsturm', 'Sandstorm'),
      Sky.precipitation => tr('Regen', 'Rain'),
    };
    return night ? tr('Nacht, $weather', 'Night, $weather') : weather;
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

  /// 0 to 1, for the change from one weather to the next.
  double opacity = 1;

  void update(double dt) {
    _time += dt;
  }

  /// [camera] is the world point in the middle of the screen, [scale] the
  /// pixels per world unit, [heading] the hull angle of the player's tank for
  /// the headlights, null without a tank. [focus] is where that tank is on
  /// the screen: the camera stops at the edge of a defense field, so it is
  /// not always the middle.
  void render(
    Canvas canvas,
    Size size, {
    required Offset camera,
    required double scale,
    double? heading,
    Offset? focus,
    bool veil = true,
  }) {
    _precipitation(canvas, size, camera, scale);
    if (veil) {
      _veil(canvas, size, scale, heading, focus);
    }
  }

  void _precipitation(Canvas canvas, Size size, Offset camera, double scale) {
    if (_particles.isEmpty) {
      return;
    }
    if (conditions.rain) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Color.fromRGBO(16, 24, 40, 0.13 * opacity),
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
        paint.color = Color.fromRGBO(
          255,
          255,
          255,
          (0.55 + 0.4 * p.seed) * opacity,
        );
        canvas.drawCircle(at, (1.2 + 1.8 * p.seed) * scale, paint);
      } else if (conditions.sand) {
        paint
          ..color = Color.fromRGBO(
            222,
            190,
            130,
            (0.35 + 0.3 * p.seed) * opacity,
          )
          ..strokeWidth = 1.4 * scale;
        canvas.drawLine(at, at + Offset(-14 * scale, 0), paint);
      } else {
        paint
          ..color = Color.fromRGBO(
            180,
            200,
            230,
            (0.25 + 0.3 * p.seed) * opacity,
          )
          ..strokeWidth = 1.1 * scale;
        canvas.drawLine(at, at + Offset(-2.5 * scale, -16 * scale), paint);
      }
    }
  }

  void _veil(
    Canvas canvas,
    Size size,
    double scale,
    double? heading,
    Offset? focus,
  ) {
    final vision = conditions.vision;
    if (vision == null) {
      return;
    }
    final Color shade;
    if (conditions.night) {
      shade = const Color(0xE6040814);
    } else if (conditions.sand) {
      shade = const Color(0xA8B9935A);
    } else {
      // Thick enough to hide what is far, light enough to still make out
      // the road and the woods.
      shade = const Color(0xA8B4BAC0);
    }
    final rect = Offset.zero & size;
    final centre = focus ?? rect.center;
    final radius = vision * scale;
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(
      rect,
      Paint()..color = shade.withValues(alpha: shade.a * opacity),
    );
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
