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
import 'package:horizont/horizont.dart';
import 'package:horizont/testing.dart';
import 'package:wargame/src/game/components/tank_painter.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/l10n/l10n.dart';
import 'package:wargame/src/tv/tv_focus_frame.dart';
import 'package:wargame/src/ui/lobby_overlay.dart';
import 'package:wargame/src/ui/theme.dart';
import 'package:wargame/src/ui/widgets/choice_row.dart';
import 'package:wargame/src/ui/widgets/legal.dart';
import 'package:wargame/src/ui/widgets/shop_tab.dart';

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
  String name, {
  Future<void> Function()? prepare,
}) async {
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
  await prepare?.call();
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

  // In Horizont's soft style the selection is the tint alone, and a control
  // in focus takes the same tint: the chosen option carries a check, so it
  // stays apart from the one the remote is on.
  testWidgets('a choice row with the focus on the television', (tester) async {
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    ChoiceRow<int> row({bool expand = false}) => ChoiceRow<int>(
      options: const [
        (0, 'LEICHT', null),
        (1, 'MITTEL', null),
        (2, 'SCHWER', null),
      ],
      selected: 0,
      expand: expand,
      onSelected: (_) {},
    );
    await _shoot(
      tester,
      TvFocusFrame(
        holdFocus: () => true,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [row(), const SizedBox(height: 24), row(expand: true)],
          ),
        ),
      ),
      const Size(390, 180),
      'choice_row_tv',
      prepare: () async {
        Focus.of(tester.element(find.text('SCHWER').first)).requestFocus();
        await tester.pump();
      },
    );
  });

  // The tabs of the defense shop: the open list is the tint with a check and
  // a semibold label, the focus the ring around another tab. Spelled out as
  // on a desktop and the television, below as icons as on a phone.
  testWidgets('the shop tabs with the focus on the television', (tester) async {
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    const style = ButtonStyle(
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: HzSpace.s12, vertical: HzSpace.s4),
      ),
      minimumSize: WidgetStatePropertyAll(Size(0, 30)),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    const iconStyle = ButtonStyle(
      padding: WidgetStatePropertyAll(EdgeInsets.zero),
      minimumSize: WidgetStatePropertyAll(Size(40, 32)),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final small = TextStyle(fontSize: HzType.caption.size);
    await _shoot(
      tester,
      TvFocusFrame(
        holdFocus: () => true,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: HzSpace.s8,
                children: [
                  ShopTab.label(
                    label: 'GESCHÜTZE',
                    open: true,
                    style: style,
                    labelStyle: small,
                    onPressed: () {},
                  ),
                  ShopTab.label(
                    label: 'AUFRÜSTUNG',
                    open: false,
                    style: style,
                    labelStyle: small,
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: HzSpace.s4,
                children: [
                  ShopTab.icon(
                    icon: HorizontSymbols.construction,
                    open: true,
                    style: iconStyle,
                    onPressed: () {},
                  ),
                  ShopTab.icon(
                    icon: HorizontSymbols.upgrade,
                    open: false,
                    style: iconStyle,
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const Size(390, 160),
      'shop_tabs_tv',
      prepare: () async {
        Focus.of(tester.element(find.text('AUFRÜSTUNG').last)).requestFocus();
        await tester.pump();
      },
    );
  });

  testWidgets('the sender over the legal links', (tester) async {
    await _shoot(
      tester,
      const Align(alignment: Alignment.bottomCenter, child: LegalLinks()),
      const Size(390, 160),
      'legal_links',
    );
  });
}
