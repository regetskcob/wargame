import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

/// The colour slots of Horizont for Panzergefecht: always dark, on the
/// game's own olive "Gelände" neutrals, with signal yellow as the one accent.
///
/// These are const mirrors of `HorizontColors.resolve(panzergefecht, dark)`,
/// so overlays and Flame painters keep their const constructors;
/// `test/ui/theme_test.dart` checks every one against the tokens, so they
/// cannot drift. Change a value in Horizont's `tokens/horizont.json`, never
/// here. The colours of the world itself (ground, teams, camouflage) belong
/// to the game and live in `game_config.dart` and `map_theme.dart`.
abstract final class GameColors {
  /// Page background: the ground behind every menu.
  static const bg = Color(0xFF141A0E);

  /// Raised surfaces: cards, sheets, fields.
  static const surface = Color(0xFF1E2616);

  /// Sunken surfaces: wells inside a card, bands, tracks of a bar.
  static const sunken = Color(0xFF0E120A);

  /// Hairlines between rows and sections.
  static const line = Color(0xFF2F3A24);

  /// The one outline of everything framed (card, field, button, chip,
  /// dialog), at least 3:1 on every surface.
  static const lineStrong = Color(0xFF667154);

  /// Ink.
  static const text = Color(0xFFE6E2D3);

  /// Secondary text, Kennungen, meta lines.
  static const textMuted = Color(0xFFB4BA9E);

  /// Decorative only, never for reading.
  static const textFaint = Color(0xFF7D8466);

  /// Fill of the one primary action: signal yellow.
  static const accent = Color(0xFFFFB300);

  /// Text and icons on [accent].
  static const onAccent = Color(0xFF1A1405);

  /// Background of the selection.
  static const accentTint = Color(0xFF2E2810);

  /// The accent as text, icon or line: the selection, the player's own.
  static const accentText = Color(0xFFFFC233);

  /// Status: good, done, healed, won.
  static const positive = Color(0xFF7FC79B);

  /// Background of [positive].
  static const positiveTint = Color(0xFF18281E);

  /// Status: attention, running low.
  static const warning = Color(0xFFEBBE6A);

  /// Background of [warning].
  static const warningTint = Color(0xFF2C2414);

  /// Status: hit, destroyed, error, irreversible.
  static const critical = Color(0xFFF0A097);

  /// Background of [critical].
  static const criticalTint = Color(0xFF301B19);

  /// Text and icons on [critical].
  static const onCritical = Color(0xFF121311);

  /// Status: note, information.
  static const info = Color(0xFF9DBBE3);

  /// Background of [info].
  static const infoTint = Color(0xFF1A2333);

  /// A HUD plate over the running round: [surface], a little see-through so
  /// the ground under the corners stays readable. The game's one deviation
  /// from opaque surfaces, as a plate floats over a moving picture.
  static const panel = Color(0xE61E2616);
}

/// The type of the game, from Horizont's three voices: Mona Sans to operate,
/// Monaspace for every value that is counted or measured, and for headlines
/// Mona Sans Display Expanded in capitals, the game's character.
///
/// Widgets uppercase the text themselves where a style says capitals, never
/// the strings in `l10n.dart`.
abstract final class GameType {
  static TextStyle _expanded(double size, double line, FontWeight weight) =>
      TextStyle(
        fontFamily: HzFont.sansExpanded,
        package: HzFont.package,
        fontSize: size,
        height: line / size,
        fontWeight: weight,
        letterSpacing: 0.02 * size,
        color: GameColors.text,
        leadingDistribution: TextLeadingDistribution.even,
      );

  /// The name of the game on the title screens. In capitals.
  static final display = _expanded(40, 44, FontWeight.w900);

  /// Headline of a screen or an overlay (round over, waiting room). In
  /// capitals.
  static final headline = _expanded(28, 34, FontWeight.w900);

  /// Title of a panel or a dialog. In capitals.
  static final title = _expanded(18, 24, FontWeight.w700);

  /// Kennung: small tracked mono capitals naming a section, an ID or a
  /// situation (`WARTERAUM · CODE UNM3C`). Uppercase the text.
  static final kennung = horizontTextStyle(
    HzType.kennung,
    GameColors.textMuted,
  );

  /// A measured value: scores, times, ammunition, codes.
  static final data = horizontTextStyle(HzType.data, GameColors.text);

  /// A value that carries a screen: the room code, the countdown, the
  /// remaining tanks.
  static final dataLarge = horizontTextStyle(
    HzType.data,
    GameColors.text,
  ).copyWith(fontSize: 28, height: 32 / 28, fontWeight: FontWeight.w600);

  /// Body text of the menus.
  static final body = horizontTextStyle(HzType.body, GameColors.text);

  /// Smaller running text and list rows.
  static final callout = horizontTextStyle(HzType.callout, GameColors.text);

  /// Labels of controls and short names.
  static final label = horizontTextStyle(HzType.label, GameColors.text);

  /// Help lines and meta text.
  static final caption = horizontTextStyle(
    HzType.caption,
    GameColors.textMuted,
  );

  /// Long reading text (help, legal): Literata.
  static final reading = horizontTextStyle(HzType.reading, GameColors.text);
}

/// The outline of everything framed, as a side for borders that are built
/// by hand (Horizont's components carry it already).
const hairline = BorderSide(color: GameColors.lineStrong);

/// Horizont's dark theme for Panzergefecht with the game's headlines.
///
/// The game has no light mode: it is played on its ground, and menus sit on
/// top of a round. Its menus keep touch density everywhere, also with a
/// pointer: they are full-screen panels played with a pad, a remote or a
/// thumb as often as with a mouse, and 28 pt controls looked lost on them.
ThemeData buildGameTheme() {
  final base = buildHorizontTheme(
    HorizontProduct.panzergefecht,
    Brightness.dark,
    density: HorizontDensity.touch,
  );
  return base.copyWith(
    // A control in focus (keyboard, remote, controller) takes the tint of
    // the selection under its focus ring instead of Material's grey.
    focusColor: GameColors.accentTint,
    textTheme: base.textTheme.copyWith(
      displayLarge: GameType.display,
      displayMedium: GameType.display,
      headlineLarge: GameType.headline,
      headlineMedium: GameType.headline,
      headlineSmall: GameType.title,
    ),
  );
}
