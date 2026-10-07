import 'package:flutter/material.dart';

/// Colours of the training ground: Flecktarn greens, sand and signal amber.
class BwColors {
  static const background = Color(0xFF161C0F);
  static const panel = Color(0xE61E2614);
  static const surface = Color(0xFF2A3520);
  static const olive = Color(0xFF6B7F3A);
  static const oliveLight = Color(0xFF8A9A5B);
  static const sand = Color(0xFFC2A878);
  static const amber = Color(0xFFFFB300);
  static const danger = Color(0xFFD1492E);
  static const text = Color(0xFFE6E2D3);
  static const textDim = Color(0xFF9DA58A);
}

const _stencil = TextStyle(
  fontFamily: 'Courier New',
  fontFamilyFallback: ['Courier', 'monospace'],
  letterSpacing: 1.2,
);

final _buttonShape = BeveledRectangleBorder(
  borderRadius: BorderRadius.circular(6),
);

ThemeData buildBundeswehrTheme() {
  const scheme = ColorScheme.dark(
    primary: BwColors.olive,
    onPrimary: BwColors.text,
    secondary: BwColors.amber,
    onSecondary: Colors.black,
    surface: BwColors.surface,
    onSurface: BwColors.text,
    error: BwColors.danger,
    outline: BwColors.oliveLight,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: BwColors.background,
    fontFamily: _stencil.fontFamily,
    fontFamilyFallback: _stencil.fontFamilyFallback,
  );
  final text = base.textTheme
      .apply(bodyColor: BwColors.text, displayColor: BwColors.text)
      .copyWith(
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
          color: BwColors.sand,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          color: BwColors.sand,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          color: BwColors.amber,
        ),
      );
  final labelStyle = _stencil.copyWith(
    fontWeight: FontWeight.w800,
    fontSize: 14,
  );
  return base.copyWith(
    textTheme: text,
    iconTheme: const IconThemeData(color: BwColors.sand),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BwColors.olive,
        foregroundColor: BwColors.text,
        disabledBackgroundColor: BwColors.surface,
        disabledForegroundColor: BwColors.textDim,
        shape: _buttonShape,
        side: const BorderSide(color: BwColors.sand, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: labelStyle,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BwColors.sand,
        shape: _buttonShape,
        side: const BorderSide(color: BwColors.sand, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: labelStyle,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: BwColors.amber,
        shape: _buttonShape,
        textStyle: labelStyle,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0x66000000),
      labelStyle: TextStyle(color: BwColors.textDim, letterSpacing: 1.5),
      floatingLabelStyle: TextStyle(color: BwColors.amber),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: BwColors.oliveLight, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: BwColors.amber, width: 2),
      ),
      counterStyle: TextStyle(color: BwColors.textDim),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: const Color(0x66000000),
        foregroundColor: BwColors.text,
        selectedBackgroundColor: BwColors.olive,
        selectedForegroundColor: BwColors.text,
        side: const BorderSide(color: BwColors.oliveLight, width: 1.5),
        shape: _buttonShape,
        textStyle: labelStyle.copyWith(fontSize: 12),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: BwColors.amber,
      selectionColor: Color(0x66FFB300),
      selectionHandleColor: BwColors.amber,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: BwColors.olive,
      linearTrackColor: Color(0x55000000),
    ),
    dividerTheme: const DividerThemeData(color: BwColors.oliveLight),
  );
}
