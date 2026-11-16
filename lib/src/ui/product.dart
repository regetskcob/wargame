import 'package:flutter/widgets.dart';
import 'package:horizont/horizont.dart';

/// Panzergefecht as a product on Horizont: the accent "Signalgelb" and the glyph.
///
/// Since Horizont 0.16.0 these decisions live here, not in Horizont. The
/// values mirror `tool/horizont/horizont.product.json` (the form Horizont's
/// web layer and tools read); `test/ui/product_test.dart` holds the two together and
/// checks the colours against Horizont's contrast rules. Change a colour in
/// both files.
const panzergefecht = HorizontProduct(
  id: 'panzergefecht',
  displayName: 'Panzergefecht',
  accentName: 'Signalgelb',
  light: HzAccent(
    accent: Color(0xFF8F6400),
    onAccent: Color(0xFFFFFFFF),
    accentTint: Color(0xFFF5ECD6),
    accentText: Color(0xFF7F5900),
  ),
  dark: HzAccent(
    accent: Color(0xFFFFB300),
    onAccent: Color(0xFF1A1405),
    accentTint: Color(0xFF2E2810),
    accentText: Color(0xFFFFC233),
  ),
  neutralDark: HzNeutrals(
    bg: Color(0xFF141A0E),
    surface: Color(0xFF1E2616),
    sunken: Color(0xFF0E120A),
    line: Color(0xFF2F3A24),
    lineStrong: Color(0xFF667154),
    text: Color(0xFFE6E2D3),
    textMuted: Color(0xFFB4BA9E),
    textFaint: Color(0xFF7D8466),
  ),
  mark: HorizontGlyph(_tank),
);

// The tank in side view on the line. Drawn in a box of 100 by 100 with the
// horizon at 66.7; `HorizontMark` strokes it 7 wide with square caps. The
// source is `tool/horizont/mark/glyph.svg`.
Path _tank() => Path()
  // The horizon.
  ..moveTo(4, 66.7)
  ..lineTo(96, 66.7)
  // The hull.
  ..moveTo(24, 66.7)
  ..lineTo(28, 54.7)
  ..lineTo(72, 54.7)
  ..lineTo(76, 66.7)
  // The turret.
  ..moveTo(40, 54.7)
  ..lineTo(40, 44)
  ..lineTo(58, 44)
  ..lineTo(58, 54.7)
  // The gun.
  ..moveTo(58, 49)
  ..lineTo(82, 49);
