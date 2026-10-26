import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:horizont/horizont.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/ui/spectator_overlay.dart';
import 'package:wargame/src/ui/theme.dart';
import 'package:wargame/src/ui/widgets/panel.dart';

import '../helpers/fakes.dart';

// Issue 21: the way out of a replay floated on its own low in the field,
// apart from the bar at the top with the next tank. Both belong in the bar.
void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  for (final size in const [Size(1280, 720), Size(390, 844)]) {
    testWidgets('the end of a replay sits in the bar with the next tank '
        '($size)', (tester) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final game = (await tester.runAsync(
        () => loadedGame(net: FakeNet()..othersPresent = true),
      ))!;
      // A battle alone without CPU tanks ends with the own tank, and leaves
      // a replay behind.
      await tester.runAsync(() async {
        game
          ..fillWithBots.value = false
          ..chooseMode(GameMode.multi)
          ..startRound(startedAt: clock.now().millisecondsSinceEpoch - 1);
        for (var i = 0; i < 15; i++) {
          game.update(1 / 30);
          await Future<void>.delayed(Duration.zero);
        }
        game.onLocalDeath(null);
        for (var i = 0; i < 15; i++) {
          game.update(1 / 30);
          await Future<void>.delayed(Duration.zero);
        }
      });
      expect(game.phase.value, GamePhase.roundOver);

      await tester.runAsync(() async {
        game.watchReplay();
        game.update(0);
      });
      expect(game.replaying.value, isTrue);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildGameTheme(),
          home: Scaffold(body: SpectatorOverlay(game: game)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final end = find.ancestor(
        of: find.textContaining('BEENDEN'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      final next = find.ancestor(
        of: find.textContaining('NÄCHSTER PANZER'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(end, findsOneWidget);
      expect(next, findsOneWidget);
      Finder panelOf(Finder button) =>
          find.ancestor(of: button, matching: find.byType(Panel)).first;
      expect(tester.element(panelOf(end)), same(tester.element(panelOf(next))));
      // In the upper part of the screen, where the bar is, not low in the
      // field.
      expect(tester.getCenter(end).dy, lessThan(size.height / 2));

      // The whole map from above and back behind the tank, without the bar
      // changing its width.
      final width = tester.getSize(panelOf(end)).width;
      final following = game.camera.viewfinder.zoom;
      await tester.tap(find.byIcon(HorizontSymbols.map));
      await tester.pump();
      expect(game.replayMap.value, isTrue);
      expect(game.wholeMap, isTrue);
      expect(game.camera.viewfinder.zoom, lessThan(following));
      expect(game.camera.viewfinder.position, Vector2.zero());
      expect(tester.getSize(panelOf(end)).width, width);
      // The arena fits on the screen.
      expect(
        2 * GameConfig.worldRadius * game.camera.viewfinder.zoom,
        lessThanOrEqualTo(min(game.canvasSize.x, game.canvasSize.y)),
      );
      await tester.tap(find.byIcon(HorizontSymbols.map));
      await tester.pump();
      expect(game.replayMap.value, isFalse);
      expect(game.camera.viewfinder.zoom, following);
      expect(tester.getSize(panelOf(end)).width, width);

      await tester.runAsync(() async => game.stopReplay());
      expect(game.replaying.value, isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
