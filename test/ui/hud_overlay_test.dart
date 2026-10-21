import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horizont/horizont.dart';
import 'package:wargame/src/ui/theme.dart';
import 'package:wargame/src/game/bot_level.dart';
import 'package:wargame/src/game/components/power_up.dart';
import 'package:wargame/src/game/defense/tower.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/net/payloads/defense_payload.dart';
import 'package:wargame/src/tv/tv_input.dart';
import 'package:wargame/src/ui/hud_overlay.dart';
import 'package:wargame/src/ui/widgets/panel.dart';
import 'package:wargame/src/ui/widgets/vitals_plate.dart';

import '../helpers/fakes.dart';

void main() {
  // Simulator test after the Horizont redesign: on a laptop browser the
  // gauges stood 72 px off the edge for an inventory that showed nothing.
  testWidgets('the gauges step in only while the inventory holds something', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1024, 768)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final game = (await tester.runAsync(loadedGame))!;
    // Normal: ammunition and fuel add two plates under the armour.
    game
      ..update(0)
      ..chooseLevel(BotLevel.normal)
      ..chooseMode(GameMode.defense)
      ..startRound();
    game.touchMode.value = false;
    game.compactHud.value = false;
    game.defense.value = DefensePayload(id: game.myId, hp: 900, wave: 2);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildGameTheme(),
        home: Scaffold(body: HudOverlay(game: game)),
      ),
    );
    final armour = find.textContaining('PANZERUNG');
    expect(tester.getRect(armour.first).left, lessThan(60));

    game.inventory.add(PowerUpType.repair);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.getRect(armour.first).left, greaterThan(72));
  });

  // TestFlight feedback from an iPhone 15 Pro: upright, the defense panel in
  // the top right ran over the gauges in the top left.
  testWidgets('the defense panel keeps clear of the gauges on an upright '
      'phone', (tester) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3
      ..padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
    addTearDown(tester.view.reset);

    final game = (await tester.runAsync(loadedGame))!;
    game
      ..update(0)
      ..chooseMode(GameMode.defense)
      ..startRound();
    game.touchMode.value = true;
    game.credits.value = 3080;
    game.defense.value = DefensePayload(
      id: game.myId,
      hp: 900,
      wave: 14,
      extended: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildGameTheme(),
        home: Scaffold(body: HudOverlay(game: game)),
      ),
    );
    // The fullest state: the guns to build folded out.
    final towers = find.byIcon(HorizontSymbols.construction);
    await tester.tap(towers);
    await tester.pump();

    expect(tester.takeException(), isNull);
    final gauges = tester.getRect(find.byType(VitalsPlate));
    final panel = tester.getRect(
      find.ancestor(of: towers, matching: find.byType(Panel)).first,
    );
    expect(panel.right, lessThanOrEqualTo(393));
    expect(panel.left, greaterThanOrEqualTo(gauges.right));
  });

  // TestFlight feedback: the gun built last stayed filled in the list and
  // looked picked, or as the one thing the funds still reached.
  testWidgets('the guns to build are only bright or faint, never marked', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final game = (await tester.runAsync(loadedGame))!;
    game
      ..update(0)
      ..chooseMode(GameMode.defense)
      ..startRound();
    game.touchMode.value = true;
    game.towerChoice.value = TowerKind.flak;
    game.credits.value = 25;
    game.defense.value = DefensePayload(id: game.myId, hp: 900, wave: 3);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildGameTheme(),
        home: Scaffold(body: HudOverlay(game: game)),
      ),
    );
    await tester.tap(find.byIcon(HorizontSymbols.construction));
    await tester.pump();

    final flak = find.ancestor(
      of: find.textContaining(TowerKind.flak.label),
      matching: find.byType(OutlinedButton),
    );
    expect(flak, findsOneWidget);
    expect(tester.widget<OutlinedButton>(flak).onPressed, isNull);
    expect(
      find.ancestor(
        of: find.textContaining(TowerKind.flak.label),
        matching: find.byType(FilledButton),
      ),
      findsNothing,
    );
  });

  // Apple TV, 1.6.0: the remote reached only the first gun and upgrade and
  // could not leave a round. Menu now hands the focus to the round menu.
  testWidgets('on a television Menu opens the defense panel as a menu', (
    tester,
  ) async {
    onAndroidTvForTesting = true;
    addTearDown(() => onAndroidTvForTesting = false);
    tester.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final game = (await tester.runAsync(loadedGame))!;
    game
      ..update(0)
      ..chooseMode(GameMode.defense)
      ..startRound();
    game.credits.value = 500;
    game.defense.value = DefensePayload(id: game.myId, hp: 900, wave: 3);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildGameTheme(),
        home: Scaffold(body: HudOverlay(game: game)),
      ),
    );
    expect(find.text('WEITERSPIELEN'), findsNothing);

    game.tvMenu.value = true;
    await tester.pump();
    await tester.pump();
    expect(find.text('WEITERSPIELEN'), findsOneWidget);
    // The focus sits on the menu's first button, the swipes walk the guns.
    final first = FocusManager.instance.primaryFocus!;
    expect(
      find.descendant(
        of: find.byElementPredicate((e) => e == first.context),
        matching: find.text('WEITERSPIELEN'),
      ),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNot(first));

    // Leaving asks first, play/pause presses what has the focus.
    first.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
    await tester.pump();
    expect(game.leaveAsked.value, isTrue);
    expect(game.tvMenu.value, isFalse);
  });
}
