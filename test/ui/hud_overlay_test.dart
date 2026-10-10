import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/net/payloads/defense_payload.dart';
import 'package:wargame/src/ui/hud_overlay.dart';
import 'package:wargame/src/ui/widgets/panel.dart';
import 'package:wargame/src/ui/widgets/vitals_plate.dart';

import '../helpers/fakes.dart';

void main() {
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
        home: Scaffold(body: HudOverlay(game: game)),
      ),
    );
    // The fullest state: the guns to build folded out.
    await tester.tap(find.text('TÜRME'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    final gauges = tester.getRect(find.byType(VitalsPlate));
    final panel = tester.getRect(
      find.ancestor(of: find.text('TÜRME'), matching: find.byType(Panel)).first,
    );
    expect(panel.right, lessThanOrEqualTo(393));
    expect(panel.left, greaterThanOrEqualTo(gauges.right));
  });
}
