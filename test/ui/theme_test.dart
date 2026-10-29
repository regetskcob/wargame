import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horizont/horizont.dart';
import 'package:wargame/src/ui/theme.dart';

void main() {
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
