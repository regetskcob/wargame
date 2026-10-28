import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

/// The colour slots of Horizont for Panzergefecht: always dark, on the
/// game's own olive "Gelände" neutrals, with signal yellow as the one accent.
///
/// Every slot is read from `HorizontColors.resolve(panzergefecht, dark)`, so
/// the values live only in Horizont's `tokens/horizont.json`. They are
/// `final`, not `const`: overlays read them at build time like any theme
/// value. The colours of the world itself (ground, teams, camouflage) belong
/// to the game and live in `game_config.dart` and `map_theme.dart`.
abstract final class GameColors {
  static final _c = HorizontColors.resolve(
    HorizontProduct.panzergefecht,
    Brightness.dark,
  );

  /// Page background: the ground behind every menu.
  static final bg = _c.bg;

  /// Raised surfaces: cards, sheets, fields.
  static final surface = _c.surface;

  /// Sunken surfaces: wells inside a card, bands, tracks of a bar.
  static final sunken = _c.sunken;

  /// Hairlines between rows and sections.
  static final line = _c.line;

  /// The one outline of everything framed (card, field, button, chip,
  /// dialog), at least 3:1 on every surface.
  static final lineStrong = _c.lineStrong;

  /// Ink.
  static final text = _c.text;

  /// Secondary text, Kennungen, meta lines.
  static final textMuted = _c.textMuted;

  /// Decorative only, never for reading.
  static final textFaint = _c.textFaint;

  /// Fill of the one primary action: signal yellow.
  static final accent = _c.accent;

  /// Text and icons on [accent].
  static final onAccent = _c.onAccent;

  /// Background of the selection.
  static final accentTint = _c.accentTint;

  /// The accent as text, icon or line: the selection, the player's own.
  static final accentText = _c.accentText;

  /// Status: good, done, healed, won.
  static final positive = _c.positive;

  /// Background of [positive].
  static final positiveTint = _c.positiveTint;

  /// Status: attention, running low.
  static final warning = _c.warning;

  /// Background of [warning].
  static final warningTint = _c.warningTint;

  /// Status: hit, destroyed, error, irreversible.
  static final critical = _c.critical;

  /// Background of [critical].
  static final criticalTint = _c.criticalTint;

  /// Text and icons on [critical].
  static final onCritical = _c.onCritical;

  /// Status: note, information.
  static final info = _c.info;

  /// Background of [info].
  static final infoTint = _c.infoTint;

  /// A HUD plate over the running round: [surface] at 90 %, so the ground
  /// under the corners stays readable. Game-only: Horizont's surfaces are
  /// opaque, but a plate here floats over a moving picture, so the
  /// see-through stays with the game and is derived, not a token.
  static final panel = _c.surface.withAlpha(0xE6);
}

/// The type of the game, from Horizont's three voices: Mona Sans to operate,
/// Monaspace for every value that is counted or measured, and for headlines
/// Mona Sans Display Expanded in capitals, the game's character.
///
/// Widgets uppercase the text themselves where a style says capitals, never
/// the strings in `l10n.dart`.
///
/// The three Expanded headlines are the one place where the game leaves
/// Horizont's type scale, as CLAUDE.md of Horizont allows: Display Expanded
/// in capitals runs much wider than Literata, so each sits a step
/// under its Literata counterpart to keep the same measure on a phone:
/// display 40/44 (scale 44/48), headline 28/34 (scale 30/36), title 18/24
/// (scale title-3 17/24, same line). Everything else is a step of the scale.
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
  /// remaining tanks. Monaspace at the size, line and weight of `title-1`,
  /// as the scale has no larger mono step.
  static final dataLarge = horizontTextStyle(HzType.data, GameColors.text)
      .copyWith(
        fontSize: HzType.title1.size,
        height: HzType.title1.line / HzType.title1.size,
        fontWeight: HzType.title1.weight,
      );

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
final hairline = BorderSide(color: GameColors.lineStrong);

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
