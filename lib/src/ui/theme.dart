import 'package:flutter/material.dart';

/// Colours of the training ground: Flecktarn greens, sand and signal amber.
class GameColors {
  static const background = Color(0xFF161C0F);
  static const panel = Color(0xE61E2614);
  static const surface = Color(0xFF2A3520);
  static const olive = Color(0xFF6B7F3A);
  static const oliveLight = Color(0xFF8A9A5B);
  static const sand = Color(0xFFC2A878);
  static const amber = Color(0xFFFFB300);
  static const danger = Color(0xFFD1492E);
  static const text = Color(0xFFE6E2D3);
  static const textDim = Color(0xFFBFC6AA);
}

const _stencil = TextStyle(fontFamily: 'Roboto', letterSpacing: 1.2);

/// Buttons keep to a plain, softly rounded shape: the beveled corners
/// belong to panels and cards, so a button inside one does not repeat its
/// frame.
final _buttonShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(4),
);

/// The one thin line of a secondary button or an idle choice.
const hairline = BorderSide(color: Color(0x998A9A5B));

ThemeData buildGameTheme() {
  const scheme = ColorScheme.dark(
    primary: GameColors.olive,
    onPrimary: GameColors.text,
    secondary: GameColors.amber,
    onSecondary: Colors.black,
    surface: GameColors.surface,
    onSurface: GameColors.text,
    error: GameColors.danger,
    outline: GameColors.oliveLight,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: GameColors.background,
    fontFamily: _stencil.fontFamily,
    fontFamilyFallback: _stencil.fontFamilyFallback,
  );
  final text = base.textTheme
      .apply(bodyColor: GameColors.text, displayColor: GameColors.text)
      .copyWith(
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
          color: GameColors.sand,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          color: GameColors.sand,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          color: GameColors.amber,
        ),
      );
  final labelStyle = _stencil.copyWith(
    fontWeight: FontWeight.w700,
    fontSize: 13,
    letterSpacing: 1.5,
  );
  return base.copyWith(
    textTheme: text,
    iconTheme: const IconThemeData(color: GameColors.sand),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: GameColors.olive,
        foregroundColor: GameColors.text,
        disabledBackgroundColor: GameColors.surface,
        disabledForegroundColor: GameColors.textDim,
        shape: _buttonShape,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        minimumSize: const Size(0, 44),
        textStyle: labelStyle,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: GameColors.sand,
        shape: _buttonShape,
        side: hairline,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        minimumSize: const Size(0, 44),
        textStyle: labelStyle,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: GameColors.amber,
        shape: _buttonShape,
        textStyle: labelStyle,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0x44000000),
      labelStyle: const TextStyle(
        color: GameColors.textDim,
        letterSpacing: 1.5,
      ),
      floatingLabelStyle: const TextStyle(color: GameColors.amber),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: hairline,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: GameColors.amber),
      ),
      counterStyle: const TextStyle(color: GameColors.textDim),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: const Color(0x66000000),
        foregroundColor: GameColors.text,
        selectedBackgroundColor: GameColors.olive,
        selectedForegroundColor: GameColors.text,
        side: hairline,
        shape: _buttonShape,
        textStyle: labelStyle.copyWith(fontSize: 12),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: GameColors.amber,
      selectionColor: Color(0x66FFB300),
      selectionHandleColor: GameColors.amber,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: GameColors.olive,
      linearTrackColor: Color(0x55000000),
    ),
    dividerTheme: const DividerThemeData(color: GameColors.oliveLight),
    // Dialogs and tooltips in the same beveled shape as every panel.
    dialogTheme: DialogThemeData(
      backgroundColor: GameColors.surface,
      shape: BeveledRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: GameColors.oliveLight, width: 1.5),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: ShapeDecoration(
        color: const Color(0xF01E2614),
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: GameColors.oliveLight),
        ),
      ),
      textStyle: const TextStyle(color: GameColors.text, fontSize: 12),
    ),
  );
}
