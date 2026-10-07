import 'dart:math';
import 'dart:ui';

/// The vehicles a player can pick, all drawn in code from above.
enum TankType {
  leopard('LEOPARD 2', 'Kampfpanzer', level: 3),
  puma('PUMA', 'Schützenpanzer'),
  gepard('GEPARD', 'Flugabwehr', level: 2),
  boxer('BOXER', 'Radpanzer'),
  wiesel('WIESEL', 'Waffenträger'),

  /// Rheinmetall's tracked infantry fighting vehicle with the 35 mm gun.
  lynx('LYNX KF41', 'Schützenpanzer', level: 5),

  /// Rheinmetall's main battle tank with the 130 mm gun.
  panther('PANTHER KF51', 'Kampfpanzer', level: 8),

  /// The self-propelled howitzer with the 155 mm gun and its big turret at
  /// the back. New vehicles always go at the end: the index travels over
  /// the wire and is kept in the players' looks.
  pzh('PZH 2000', 'Panzerhaubitze', level: 4);

  const TankType(this.label, this.role, {this.level = 1});

  final String label;
  final String role;

  /// Rank a pilot needs to drive it. New vehicles come with promotions.
  final int level;
}

const _steel = Color(0xFF262626);
const _barrelTip = Color(0xFF555555);
const _trackColor = Color(0xFF151515);
const _trackMark = Color(0xFF3A3A3A);

/// Barrel tips on the 48 grid, where the muzzle flash appears.
const _muzzles = {
  TankType.leopard: [Offset(24, -18)],
  TankType.puma: [Offset(24, -9)],
  TankType.gepard: [Offset(18.5, -11), Offset(29.6, -11)],
  TankType.boxer: [Offset(24, -5)],
  TankType.wiesel: [Offset(27.5, 0)],
  TankType.lynx: [Offset(26, -9)],
  TankType.panther: [Offset(24, -22)],
  TankType.pzh: [Offset(24, -21)],
};

/// Where the turret ring sits on the hull.
const _pivots = {
  TankType.leopard: Offset(24, 24),
  TankType.puma: Offset(24, 23),
  TankType.gepard: Offset(24, 24),
  TankType.boxer: Offset(24, 24),
  TankType.wiesel: Offset(24, 27),
  TankType.lynx: Offset(24, 22),
  TankType.panther: Offset(24, 25),
  TankType.pzh: Offset(24, 32),
};

typedef _TurretPass = void Function(void Function() draw);

/// Paints [type] into a square of [size] pixels, forward is up. The barrel
/// reaches above the square, so give the canvas some room.
///
/// The turret turns by [turretAngle] radians against the hull, [recoil]
/// (0 to 1) slides it back and [flash] (0 to 1) lights the muzzle.
///
/// [wear] (0 to 1) blackens the paint and punches holes, scorch marks and
/// scratches into hull and turret, laid out by [scarSeed] so every tank keeps
/// its own scars. [flame] is a running time in seconds that animates a fire
/// on the engine deck, null for none.
void paintTank(
  Canvas canvas,
  double size,
  TankType type,
  Color hull, {
  Color? deck,
  double turretAngle = 0,
  double recoil = 0,
  double flash = 0,
  double wear = 0,
  int scarSeed = 0,
  double? flame,
}) {
  if (wear > 0) {
    hull = Color.lerp(hull, const Color(0xFF1B1712), 0.4 * wear)!;
    deck = deck == null
        ? null
        : Color.lerp(deck, const Color(0xFF1B1712), 0.4 * wear)!;
  }
  final scars = wear > 0 ? _scars(scarSeed, wear) : const <_Scar>[];
  final dark = Color.lerp(hull, const Color(0xFF000000), 0.5)!;
  final light = deck ?? Color.lerp(hull, const Color(0xFFFFFFFF), 0.14)!;
  final pivot = _pivots[type]!;
  void turret(void Function() draw) {
    // The hull is complete when the turret goes on, so its scars go here.
    for (final scar in scars) {
      if (!scar.onTurret) {
        scar.paint(canvas);
      }
    }
    if (flame != null) {
      _engineFire(canvas, flame);
    }
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(turretAngle);
    canvas.translate(0, recoil * 2.5);
    canvas.translate(-pivot.dx, -pivot.dy);
    draw();
    for (final scar in scars) {
      if (scar.onTurret) {
        scar.paint(canvas, around: pivot);
      }
    }
    if (flash > 0) {
      for (final muzzle in _muzzles[type]!) {
        _muzzleFlash(canvas, muzzle, flash);
      }
    }
    canvas.restore();
  }

  canvas.save();
  canvas.scale(size / 48);
  switch (type) {
    case TankType.leopard:
      _leopard(canvas, hull, dark, light, turret);
    case TankType.puma:
      _puma(canvas, hull, dark, light, turret);
    case TankType.gepard:
      _gepard(canvas, hull, dark, light, turret);
    case TankType.boxer:
      _boxer(canvas, hull, dark, light, turret);
    case TankType.wiesel:
      _wiesel(canvas, hull, dark, light, turret);
    case TankType.lynx:
      _lynx(canvas, hull, dark, light, turret);
    case TankType.panther:
      _panther(canvas, hull, dark, light, turret);
    case TankType.pzh:
      _pzh(canvas, hull, dark, light, turret);
  }
  canvas.restore();
}

void _muzzleFlash(Canvas canvas, Offset tip, double flash) {
  final reach = 6 + 7 * flash;
  final star = Path()
    ..moveTo(tip.dx, tip.dy - reach)
    ..lineTo(tip.dx + 2.4, tip.dy - 1)
    ..lineTo(tip.dx + reach * 0.7, tip.dy - 2)
    ..lineTo(tip.dx + 2, tip.dy + 1)
    ..lineTo(tip.dx, tip.dy + 3)
    ..lineTo(tip.dx - 2, tip.dy + 1)
    ..lineTo(tip.dx - reach * 0.7, tip.dy - 2)
    ..lineTo(tip.dx - 2.4, tip.dy - 1)
    ..close();
  canvas.drawPath(
    star,
    Paint()..color = const Color(0xFFFFB300).withValues(alpha: 0.9 * flash),
  );
  canvas.drawCircle(
    tip,
    2.4,
    Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: flash),
  );
}

enum _ScarKind { hole, scorch, scratch }

/// One mark of battle damage on the 48 grid.
class _Scar {
  const _Scar(this.kind, this.at, this.size, this.angle, this.onTurret);

  final _ScarKind kind;
  final Offset at;
  final double size;
  final double angle;

  /// Turret scars sit relative to the turret pivot and turn with it.
  final bool onTurret;

  void paint(Canvas canvas, {Offset around = Offset.zero}) {
    final c = at + around;
    switch (kind) {
      case _ScarKind.scorch:
        canvas.drawCircle(
          c,
          size * 2,
          Paint()
            ..shader = Gradient.radial(c, size * 2, const [
              Color(0xE60E0B08),
              Color(0x000E0B08),
            ]),
        );
      case _ScarKind.hole:
        canvas.drawCircle(c, size * 0.85, _fill(const Color(0xAAB8B0A0)));
        canvas.drawCircle(c, size * 0.55, _fill(const Color(0xFF0A0806)));
        final crack = _line(const Color(0xCC0A0806), 0.6);
        for (var i = 0; i < 3; i++) {
          final a = angle + i * 2.1;
          canvas.drawLine(
            c + Offset(cos(a), sin(a)) * size * 0.5,
            c + Offset(cos(a), sin(a)) * size * 1.4,
            crack,
          );
        }
      case _ScarKind.scratch:
        final d = Offset(cos(angle), sin(angle)) * size;
        canvas.drawLine(c - d, c + d, _line(const Color(0xCCD8D2C4), 0.7));
    }
  }
}

/// Scars that [wear] has uncovered. They appear one after the other as the
/// tank takes hits, always in the same spots for the same [seed].
List<_Scar> _scars(int seed, double wear) {
  final random = Random(seed);
  final scars = <_Scar>[];
  for (var i = 0; i < 9; i++) {
    // Draw every value even for hidden scars to keep the layout stable.
    final kind = _ScarKind.values[random.nextInt(_ScarKind.values.length)];
    final onTurret = i % 3 == 1;
    // Hull scars go on the bow, the engine deck or the flanks, where the
    // turret does not cover them.
    final zone = random.nextInt(3);
    final u = random.nextDouble();
    final v = random.nextDouble();
    final at = onTurret
        ? Offset(u * 10 - 5, v * 10 - 5)
        : switch (zone) {
            0 => Offset(19 + u * 10, 9 + v * 5),
            1 => Offset(17.5 + u * 13, 36 + v * 8),
            _ => Offset(u < 0.5 ? 16.5 + v * 1.5 : 30 + v * 1.5, 14 + u * 22),
          };
    final size = 2 + random.nextDouble() * 1.8;
    final angle = random.nextDouble() * 2 * pi;
    if (wear >= 0.08 + i * 0.09) {
      scars.add(_Scar(kind, at, size, angle, onTurret));
    }
  }
  return scars;
}

/// Flickering flames over the engine deck.
void _engineFire(Canvas canvas, double time) {
  const base = Offset(24, 41);
  for (var i = 0; i < 3; i++) {
    final phase = time * (9 + i * 3.7) + i * 2;
    final r = 3.4 + sin(phase) * 0.9 - i * 0.7;
    final c = base + Offset(sin(phase * 0.7) * 1.6 + (i - 1) * 2.4, -i * 1.4);
    canvas.drawCircle(
      c,
      r + 1.8,
      _fill(const Color(0xFFE65100).withValues(alpha: 0.55)),
    );
    canvas.drawCircle(c, r, _fill(const Color(0xFFFFA000)));
    canvas.drawCircle(c, r * 0.45, _fill(const Color(0xFFFFF59D)));
  }
}

Paint _fill(Color color) => Paint()..color = color;

Paint _line(Color color, [double width = 0.8]) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..color = color;

void _tracks(Canvas canvas, double top, double bottom, double inset) {
  for (final x in [inset, 48 - inset - 6]) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x, top, x + 6, bottom),
        const Radius.circular(2.5),
      ),
      _fill(_trackColor),
    );
    for (var y = top + 4; y < bottom - 3; y += 4.2) {
      canvas.drawRect(Rect.fromLTWH(x + 1, y, 4, 1.2), _fill(_trackMark));
    }
  }
}

void _skirts(Canvas canvas, Color dark, double top, double bottom) {
  for (final x in const [8.5, 37.5]) {
    for (var y = top; y < bottom - 6; y += 7.2) {
      canvas.drawRect(Rect.fromLTWH(x, y, 2, 6.4), _fill(dark));
    }
  }
}

void _balkenkreuz(Canvas canvas, double cx, double cy, double s) {
  final cross = _fill(const Color(0xFFF2F2F2));
  canvas.drawRect(
    Rect.fromCenter(center: Offset(cx, cy), width: s * 0.33, height: s),
    cross,
  );
  canvas.drawRect(
    Rect.fromCenter(center: Offset(cx, cy), width: s, height: s * 0.33),
    cross,
  );
}

void _leopard(
  Canvas canvas,
  Color hull,
  Color dark,
  Color light,
  _TurretPass turret,
) {
  _tracks(canvas, 4, 47, 10);
  _skirts(canvas, dark, 9, 44);

  final body = Path()
    ..moveTo(16, 46)
    ..lineTo(16, 15)
    ..lineTo(19, 6)
    ..lineTo(29, 6)
    ..lineTo(32, 15)
    ..lineTo(32, 46)
    ..close();
  canvas.drawPath(body, _fill(hull));
  canvas.drawPath(body, _line(dark));
  canvas.drawRect(const Rect.fromLTWH(18, 37, 12, 8), _fill(dark));
  for (var y = 38.0; y < 45; y += 2) {
    canvas.drawLine(Offset(18.5, y), Offset(29.5, y), _line(light, 0.6));
  }
  canvas.drawLine(const Offset(17, 15), const Offset(31, 15), _line(dark));
  _balkenkreuz(canvas, 24, 41.5, 6);

  turret(() {
    // Smooth bore gun with bore evacuator
    canvas.drawRect(const Rect.fromLTWH(22.9, -17, 2.2, 31), _fill(_steel));
    canvas.drawRect(const Rect.fromLTWH(22.2, -6, 3.6, 5), _fill(_steel));
    canvas.drawRect(
      const Rect.fromLTWH(22.4, -17.5, 3.2, 1.6),
      _fill(_barrelTip),
    );
    canvas.drawRect(const Rect.fromLTWH(20, 11, 8, 3.5), _fill(_steel));

    // Wedge shaped turret
    final turret = Path()
      ..moveTo(21, 12)
      ..lineTo(27, 12)
      ..lineTo(31, 18)
      ..lineTo(33, 28)
      ..lineTo(30, 34)
      ..lineTo(18, 34)
      ..lineTo(15, 28)
      ..lineTo(17, 18)
      ..close();
    canvas.drawPath(turret, _fill(light));
    canvas.drawPath(turret, _line(dark));
    canvas.drawLine(const Offset(24, 12), const Offset(24, 34), _line(dark));
    canvas.drawLine(const Offset(17, 18), const Offset(31, 18), _line(dark));
    canvas.drawRect(const Rect.fromLTWH(13.2, 19, 2, 7), _fill(dark));
    canvas.drawRect(const Rect.fromLTWH(32.8, 19, 2, 7), _fill(dark));
    canvas.drawCircle(const Offset(28, 25), 2.6, _fill(dark));
    canvas.drawCircle(const Offset(28, 25), 1.4, _fill(light));
    canvas.drawCircle(const Offset(20, 27), 2.4, _fill(dark));
  });
}

void _puma(
  Canvas canvas,
  Color hull,
  Color dark,
  Color light,
  _TurretPass turret,
) {
  _tracks(canvas, 8, 47, 11);
  _skirts(canvas, dark, 12, 44);

  final body = Path()
    ..moveTo(15, 46)
    ..lineTo(15, 18)
    ..lineTo(19, 8)
    ..lineTo(29, 8)
    ..lineTo(33, 18)
    ..lineTo(33, 46)
    ..close();
  canvas.drawPath(body, _fill(hull));
  canvas.drawPath(body, _line(dark));
  // Rear ramp and engine hatches
  canvas.drawRect(const Rect.fromLTWH(18, 38, 12, 7), _fill(dark));
  canvas.drawLine(
    const Offset(24, 38),
    const Offset(24, 45),
    _line(light, 0.6),
  );
  canvas.drawLine(const Offset(15, 36), const Offset(33, 36), _line(dark));
  _balkenkreuz(canvas, 24, 42, 5);

  turret(() {
    // 30 mm autocannon
    canvas.drawRect(const Rect.fromLTWH(23.3, -8, 1.5, 24), _fill(_steel));
    canvas.drawRect(
      const Rect.fromLTWH(22.8, -8.5, 2.4, 1.6),
      _fill(_barrelTip),
    );

    // Compact square turret with a Spike launcher and the sight
    final turret = RRect.fromRectAndRadius(
      const Rect.fromLTWH(16.5, 15, 15, 16),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(turret, _fill(light));
    canvas.drawRRect(turret, _line(dark));
    canvas.drawRect(const Rect.fromLTWH(31.5, 17, 3.6, 9), _fill(dark));
    canvas.drawRect(const Rect.fromLTWH(32.1, 17.6, 2.4, 2.6), _fill(_steel));
    canvas.drawCircle(const Offset(21.5, 24), 2.6, _fill(dark));
    canvas.drawRect(const Rect.fromLTWH(24.5, 17, 5, 3), _fill(dark));
  });
}

void _gepard(
  Canvas canvas,
  Color hull,
  Color dark,
  Color light,
  _TurretPass turret,
) {
  _tracks(canvas, 5, 47, 10);
  _skirts(canvas, dark, 10, 44);

  final body = Path()
    ..moveTo(15, 46)
    ..lineTo(15, 14)
    ..lineTo(19, 7)
    ..lineTo(29, 7)
    ..lineTo(33, 14)
    ..lineTo(33, 46)
    ..close();
  canvas.drawPath(body, _fill(hull));
  canvas.drawPath(body, _line(dark));
  canvas.drawRect(const Rect.fromLTWH(18, 38, 12, 7), _fill(dark));
  canvas.drawLine(const Offset(16, 36), const Offset(32, 36), _line(dark));
  _balkenkreuz(canvas, 24, 42, 5);

  turret(() {
    // Twin 35 mm Oerlikon cannons
    for (final x in const [17.6, 28.8]) {
      canvas.drawRect(Rect.fromLTWH(x, -10, 1.7, 26), _fill(_steel));
      canvas.drawRect(
        Rect.fromLTWH(x - 0.4, -10.5, 2.5, 1.6),
        _fill(_barrelTip),
      );
    }

    // Wide box turret
    final turret = RRect.fromRectAndRadius(
      const Rect.fromLTWH(11, 15, 26, 19),
      const Radius.circular(2),
    );
    canvas.drawRRect(turret, _fill(light));
    canvas.drawRRect(turret, _line(dark));
    canvas.drawLine(const Offset(11, 21), const Offset(37, 21), _line(dark));
    // Tracking radar up front, search radar dish at the back
    canvas.drawCircle(const Offset(24, 18), 3, _fill(dark));
    canvas.drawCircle(const Offset(24, 18), 1.6, _fill(light));
    canvas.drawCircle(const Offset(24, 28.5), 5.5, _fill(dark));
    canvas.drawCircle(const Offset(24, 28.5), 4.2, _fill(light));
    canvas.drawLine(const Offset(24, 23), const Offset(24, 34), _line(dark));
    canvas.drawLine(
      const Offset(18.5, 28.5),
      const Offset(29.5, 28.5),
      _line(dark),
    );
  });
}

void _boxer(
  Canvas canvas,
  Color hull,
  Color dark,
  Color light,
  _TurretPass turret,
) {
  // Eight wheels, four per side
  for (final x in const [9.0, 34.0]) {
    for (final y in const [8.0, 17.5, 27.0, 36.5]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, 5, 8.2),
          const Radius.circular(1.6),
        ),
        _fill(_trackColor),
      );
      canvas.drawRect(Rect.fromLTWH(x + 1, y + 2, 3, 0.9), _fill(_trackMark));
      canvas.drawRect(Rect.fromLTWH(x + 1, y + 5, 3, 0.9), _fill(_trackMark));
    }
  }

  final body = Path()
    ..moveTo(14, 46)
    ..lineTo(14, 14)
    ..lineTo(18, 5)
    ..lineTo(30, 5)
    ..lineTo(34, 14)
    ..lineTo(34, 46)
    ..close();
  canvas.drawPath(body, _fill(hull));
  canvas.drawPath(body, _line(dark));
  canvas.drawLine(const Offset(15, 14), const Offset(33, 14), _line(dark));
  canvas.drawRect(const Rect.fromLTWH(17, 36, 14, 8), _fill(dark));
  canvas.drawLine(
    const Offset(24, 36),
    const Offset(24, 44),
    _line(light, 0.6),
  );
  _balkenkreuz(canvas, 24, 41, 5);

  turret(() {
    // Remote controlled turret with a 30 mm gun
    canvas.drawRect(const Rect.fromLTWH(23.3, -4, 1.5, 20), _fill(_steel));
    canvas.drawRect(
      const Rect.fromLTWH(22.8, -4.5, 2.4, 1.6),
      _fill(_barrelTip),
    );
    canvas.drawCircle(const Offset(24, 24), 8, _fill(dark));
    canvas.drawCircle(const Offset(24, 24), 6.6, _fill(light));
    canvas.drawRect(const Rect.fromLTWH(28.5, 20, 3.4, 7), _fill(dark));
    canvas.drawCircle(const Offset(20.5, 26), 2, _fill(dark));
  });
}

void _wiesel(
  Canvas canvas,
  Color hull,
  Color dark,
  Color light,
  _TurretPass turret,
) {
  // Small and low: short tracks close to a narrow hull
  _tracks(canvas, 12, 44, 12.5);

  final body = Path()
    ..moveTo(18.5, 43)
    ..lineTo(18.5, 19)
    ..lineTo(21, 12)
    ..lineTo(27, 12)
    ..lineTo(29.5, 19)
    ..lineTo(29.5, 43)
    ..close();
  canvas.drawPath(body, _fill(hull));
  canvas.drawPath(body, _line(dark));
  // Driver hatch up front, engine grille at the back
  canvas.drawRect(const Rect.fromLTWH(19.8, 15.5, 4, 3.5), _fill(dark));
  canvas.drawRect(const Rect.fromLTWH(20, 37, 8, 5), _fill(dark));
  for (var y = 38.0; y < 42; y += 1.6) {
    canvas.drawLine(Offset(20.5, y), Offset(27.5, y), _line(light, 0.5));
  }
  _balkenkreuz(canvas, 24, 33, 4);

  turret(() {
    // TOW launch tube on a pedestal, set off to the right
    canvas.drawRect(const Rect.fromLTWH(25.8, 0.5, 3.4, 27), _fill(_steel));
    canvas.drawRect(const Rect.fromLTWH(25.4, 0, 4.2, 1.8), _fill(_barrelTip));
    canvas.drawRect(const Rect.fromLTWH(26.3, 4, 2.4, 0.8), _fill(dark));
    canvas.drawCircle(const Offset(24, 27), 4.6, _fill(dark));
    canvas.drawCircle(const Offset(24, 27), 3.4, _fill(light));
    // Sight box next to the tube
    canvas.drawRect(const Rect.fromLTWH(21, 22, 3.6, 4.4), _fill(dark));
  });
}

void _lynx(
  Canvas canvas,
  Color hull,
  Color dark,
  Color light,
  _TurretPass turret,
) {
  _tracks(canvas, 5, 47, 10);
  _skirts(canvas, dark, 9, 44);

  // Long hull with a steep glacis and the power pack up front on the left.
  final body = Path()
    ..moveTo(15, 46)
    ..lineTo(15, 13)
    ..lineTo(18, 5)
    ..lineTo(30, 5)
    ..lineTo(33, 13)
    ..lineTo(33, 46)
    ..close();
  canvas.drawPath(body, _fill(hull));
  canvas.drawPath(body, _line(dark));
  canvas.drawRect(const Rect.fromLTWH(17, 8, 6, 5), _fill(dark));
  for (var x = 17.5; x < 23; x += 1.5) {
    canvas.drawLine(Offset(x, 8.5), Offset(x, 12.5), _line(light, 0.5));
  }
  // Rear door and roof hatches of the troop compartment.
  canvas.drawRect(const Rect.fromLTWH(18, 39, 12, 6), _fill(dark));
  canvas.drawLine(const Offset(24, 39), const Offset(24, 45), _line(light));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(18.5, 32, 4.5, 4.5),
      const Radius.circular(1),
    ),
    _line(dark),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(25, 32, 4.5, 4.5),
      const Radius.circular(1),
    ),
    _line(dark),
  );
  _balkenkreuz(canvas, 24, 42, 4.5);

  turret(() {
    // 35 mm Wotan gun, set off to the right of the turret.
    canvas.drawRect(const Rect.fromLTWH(25.1, -8, 1.8, 24), _fill(_steel));
    canvas.drawRect(
      const Rect.fromLTWH(24.7, -8.5, 2.6, 1.8),
      _fill(_barrelTip),
    );
    canvas.drawRect(const Rect.fromLTWH(24.6, 4, 2.8, 3), _fill(_steel));

    // Faceted Lance turret.
    final turret = Path()
      ..moveTo(18, 14)
      ..lineTo(30, 14)
      ..lineTo(33, 19)
      ..lineTo(33, 29)
      ..lineTo(30, 31)
      ..lineTo(18, 31)
      ..lineTo(15, 29)
      ..lineTo(15, 19)
      ..close();
    canvas.drawPath(turret, _fill(light));
    canvas.drawPath(turret, _line(dark));
    // Spike launcher on the left cheek, commander's sight at the back.
    canvas.drawRect(const Rect.fromLTWH(12.4, 17, 3, 9), _fill(dark));
    canvas.drawRect(const Rect.fromLTWH(12.9, 17.5, 2, 2.4), _fill(_steel));
    canvas.drawCircle(const Offset(20, 26), 2.5, _fill(dark));
    canvas.drawCircle(const Offset(20, 26), 1.2, _fill(light));
    canvas.drawRect(const Rect.fromLTWH(26, 24, 4, 3.5), _fill(dark));
  });
}

void _panther(
  Canvas canvas,
  Color hull,
  Color dark,
  Color light,
  _TurretPass turret,
) {
  _tracks(canvas, 3, 47, 9);
  _skirts(canvas, dark, 7, 45);

  // Broad hull, wider than the Leopard's.
  final body = Path()
    ..moveTo(15, 46)
    ..lineTo(15, 13)
    ..lineTo(18.5, 4.5)
    ..lineTo(29.5, 4.5)
    ..lineTo(33, 13)
    ..lineTo(33, 46)
    ..close();
  canvas.drawPath(body, _fill(hull));
  canvas.drawPath(body, _line(dark));
  canvas.drawLine(const Offset(16, 13), const Offset(32, 13), _line(dark));
  canvas.drawRect(const Rect.fromLTWH(17.5, 38, 13, 7.5), _fill(dark));
  for (var y = 39.0; y < 45; y += 1.8) {
    canvas.drawLine(Offset(18, y), Offset(30, y), _line(light, 0.6));
  }
  _balkenkreuz(canvas, 24, 41.8, 6);

  turret(() {
    // 130 mm smooth bore gun, long and thick, with a fume extractor.
    canvas.drawRect(const Rect.fromLTWH(22.6, -21, 2.8, 35), _fill(_steel));
    canvas.drawRect(const Rect.fromLTWH(21.9, -9, 4.2, 6), _fill(_steel));
    canvas.drawRect(
      const Rect.fromLTWH(22.1, -21.6, 3.8, 1.9),
      _fill(_barrelTip),
    );
    canvas.drawRect(const Rect.fromLTWH(19.5, 11, 9, 4), _fill(_steel));

    // Low, angular turret with a bustle at the back.
    final turret = Path()
      ..moveTo(20, 12)
      ..lineTo(28, 12)
      ..lineTo(33, 17)
      ..lineTo(34, 30)
      ..lineTo(32, 37)
      ..lineTo(16, 37)
      ..lineTo(14, 30)
      ..lineTo(15, 17)
      ..close();
    canvas.drawPath(turret, _fill(light));
    canvas.drawPath(turret, _line(dark));
    canvas.drawLine(const Offset(15, 30), const Offset(34, 30), _line(dark));
    // Launcher for loitering munitions on the bustle.
    canvas.drawRect(const Rect.fromLTWH(17.5, 31, 13, 5), _fill(dark));
    for (var x = 19.0; x < 30; x += 3.2) {
      canvas.drawCircle(Offset(x, 33.5), 1.1, _fill(_steel));
    }
    // Commander's and gunner's sights.
    canvas.drawCircle(const Offset(29, 22), 2.6, _fill(dark));
    canvas.drawCircle(const Offset(29, 22), 1.3, _fill(light));
    canvas.drawRect(const Rect.fromLTWH(17.5, 19, 3.6, 4), _fill(dark));
  });
}

void _pzh(
  Canvas canvas,
  Color hull,
  Color dark,
  Color light,
  _TurretPass turret,
) {
  _tracks(canvas, 3, 47, 9);
  _skirts(canvas, dark, 7, 45);

  // Long hull, the engine up front on the right, the driver beside it.
  final body = Path()
    ..moveTo(15, 46)
    ..lineTo(15, 10)
    ..lineTo(19, 3.5)
    ..lineTo(29, 3.5)
    ..lineTo(33, 10)
    ..lineTo(33, 46)
    ..close();
  canvas.drawPath(body, _fill(hull));
  canvas.drawPath(body, _line(dark));
  canvas.drawRect(const Rect.fromLTWH(25.5, 7, 6, 10), _fill(dark));
  for (var y = 8.0; y < 17; y += 1.8) {
    canvas.drawLine(Offset(26, y), Offset(31, y), _line(light, 0.6));
  }
  canvas.drawCircle(const Offset(19.5, 9.5), 2, _fill(dark));
  _balkenkreuz(canvas, 19.5, 16.5, 5);

  turret(() {
    // 155 mm gun, far longer than the hull, with a muzzle brake and a
    // thermal sleeve.
    canvas.drawRect(const Rect.fromLTWH(22.8, -19, 2.4, 42), _fill(_steel));
    canvas.drawRect(const Rect.fromLTWH(22.2, 0, 3.6, 9), _fill(_steel));
    canvas.drawRect(
      const Rect.fromLTWH(21.4, -21, 5.2, 3.2),
      _fill(_barrelTip),
    );
    canvas.drawRect(const Rect.fromLTWH(20, 20, 8, 4), _fill(_steel));

    // Big boxy turret over the back half of the hull.
    final turret = Path()
      ..moveTo(16, 23)
      ..lineTo(32, 23)
      ..lineTo(34, 26)
      ..lineTo(34, 44)
      ..lineTo(14, 44)
      ..lineTo(14, 26)
      ..close();
    canvas.drawPath(turret, _fill(light));
    canvas.drawPath(turret, _line(dark));
    canvas.drawLine(const Offset(14, 39), const Offset(34, 39), _line(dark));
    // Hatches, a machine gun ring and the shell door at the back.
    canvas.drawCircle(const Offset(19, 31), 2.6, _fill(dark));
    canvas.drawCircle(const Offset(19, 31), 1.3, _fill(light));
    canvas.drawCircle(const Offset(29, 31), 2.4, _fill(dark));
    canvas.drawRect(const Rect.fromLTWH(19, 40, 10, 3), _fill(dark));
  });
}
