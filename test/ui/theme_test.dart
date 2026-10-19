import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horizont/horizont.dart';
import 'package:wargame/src/ui/theme.dart';

void main() {
  // GameColors are const mirrors of Horizont's slots so overlays and
  // painters stay const; this keeps them from drifting off the tokens.
  test('GameColors mirror the dark Panzergefecht slots of Horizont', () {
    final c = HorizontColors.resolve(
      HorizontProduct.panzergefecht,
      Brightness.dark,
    );
    final pairs = {
      'bg': (GameColors.bg, c.bg),
      'surface': (GameColors.surface, c.surface),
      'sunken': (GameColors.sunken, c.sunken),
      'line': (GameColors.line, c.line),
      'lineStrong': (GameColors.lineStrong, c.lineStrong),
      'text': (GameColors.text, c.text),
      'textMuted': (GameColors.textMuted, c.textMuted),
      'textFaint': (GameColors.textFaint, c.textFaint),
      'accent': (GameColors.accent, c.accent),
      'onAccent': (GameColors.onAccent, c.onAccent),
      'accentTint': (GameColors.accentTint, c.accentTint),
      'accentText': (GameColors.accentText, c.accentText),
      'positive': (GameColors.positive, c.positive),
      'positiveTint': (GameColors.positiveTint, c.positiveTint),
      'warning': (GameColors.warning, c.warning),
      'warningTint': (GameColors.warningTint, c.warningTint),
      'critical': (GameColors.critical, c.critical),
      'criticalTint': (GameColors.criticalTint, c.criticalTint),
      'onCritical': (GameColors.onCritical, c.onCritical),
      'info': (GameColors.info, c.info),
      'infoTint': (GameColors.infoTint, c.infoTint),
      'panel': (GameColors.panel.withAlpha(0xFF), c.surface),
    };
    for (final MapEntry(key: name, value: (mine, token)) in pairs.entries) {
      expect(mine, token, reason: name);
    }
  });

  test('the game theme is Horizont in the dark with its extension', () {
    final theme = buildGameTheme();
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, GameColors.accent);
    expect(theme.colorScheme.surface, GameColors.bg);
    final ext = theme.extension<HorizontTheme>();
    expect(ext?.product, HorizontProduct.panzergefecht);
    expect(
      theme.textTheme.headlineLarge?.fontFamily,
      'packages/horizont/${HzFont.sansExpanded}',
    );
  });
}
