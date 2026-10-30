// Pictures of the menus in Horizont, compared pixel by pixel. The game has
// only its dark theme (lib/src/ui/theme.dart), so there is no light set.
// Fonts render differently on Linux, so CI leaves the tag out and
// tool/release.sh verify runs it on the Mac. After a wanted change:
//   flutter test test/ui/goldens_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horizont/testing.dart';
import 'package:wargame/src/game/components/tank_painter.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/l10n/l10n.dart';
import 'package:wargame/src/ui/lobby_overlay.dart';
import 'package:wargame/src/ui/theme.dart';
import 'package:wargame/src/ui/widgets/legal.dart';

import '../helpers/fakes.dart';

const _screens = {
  'phone': Size(390, 844),
  'tablet': Size(1194, 834),
  'desktop': Size(1280, 800),
};

Future<void> _shoot(
  WidgetTester tester,
  Widget child,
  Size size,
  String name,
) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Tests run as Android; the phone and the tablet are the iOS app, whose
  // menus go without the outer plate, the desktop is the Mac's window.
  debugDefaultTargetPlatformOverride = name.endsWith('desktop')
      ? TargetPlatform.macOS
      : TargetPlatform.iOS;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: AppLang.de.locale,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: [for (final l in AppLang.values) l.locale],
      theme: buildGameTheme(),
      home: Scaffold(backgroundColor: GameColors.bg, body: child),
    ),
  );
  // Past the entry animations; the menus have no endless one.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
  await tester.pumpWidget(const SizedBox());
  debugDefaultTargetPlatformOverride = null;
}

void main() {
  setUpAll(loadHorizontFonts);
  setUp(() => L10n.lang.value = AppLang.de);

  // The name and the starter tank are drawn at random; the pictures need
  // the same each time.
  Future<TankGame> game(WidgetTester tester) async =>
      (await tester.runAsync(loadedGame))!
        ..myName = 'Panzer-4711'
        ..myColorIndex = GameConfig.styleOf(TankType.hermelin.index, 0);

  for (final MapEntry(key: screen, value: size) in _screens.entries) {
    testWidgets('welcome on the $screen', (tester) async {
      final g = await game(tester);
      g.welcomed.value = false;
      await _shoot(tester, LobbyOverlay(game: g), size, 'welcome_$screen');
    });

    testWidgets('choosing the mode on the $screen', (tester) async {
      final g = await game(tester);
      g
        ..welcomed.value = true
        ..choosingMode.value = true;
      await _shoot(tester, LobbyOverlay(game: g), size, 'modes_$screen');
    });

    testWidgets('the solo waiting room on the $screen', (tester) async {
      final g = await game(tester);
      g
        ..welcomed.value = true
        ..chooseMode(GameMode.solo);
      await _shoot(tester, LobbyOverlay(game: g), size, 'solo_$screen');
    });
  }

  testWidgets('the sender over the legal links', (tester) async {
    await _shoot(
      tester,
      const Align(alignment: Alignment.bottomCenter, child: LegalLinks()),
      const Size(390, 160),
      'legal_links',
    );
  });
}
