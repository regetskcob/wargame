import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/components/power_up.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/ui/theme.dart';
import 'package:wargame/src/watch/watch_lobby.dart';
import 'package:wargame/src/watch/watch_overlays.dart';

import '../helpers/fakes.dart';

/// Logical sizes of the watches, smallest first.
const _sizes = {
  'se40': Size(162, 197),
  'w41': Size(176, 215),
  'w45': Size(198, 242),
  'ultra49': Size(205, 251),
};

void main() {
  // Set WATCH_SHOTS to a folder to get a picture of every page.
  final shots = Platform.environment['WATCH_SHOTS'];

  setUpAll(() async {
    final loader = FontLoader('Roboto');
    for (final file in ['Regular', 'Medium', 'Bold', 'Black']) {
      loader.addFont(
        File('assets/fonts/Roboto-$file.ttf')
            .readAsBytes()
            .then((bytes) => ByteData.view(bytes.buffer)),
      );
    }
    await loader.load();
  });

  Future<void> show(
    WidgetTester tester,
    String name,
    Size size,
    Widget page,
  ) async {
    final key = GlobalKey();
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1
      // The clock band on top, the rounded corners at the sides.
      ..padding = const FakeViewPadding(left: 9, top: 44, right: 9, bottom: 9)
      ..viewPadding = const FakeViewPadding(
        left: 9,
        top: 44,
        right: 9,
        bottom: 9,
      );
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildBundeswehrTheme(),
        home: Scaffold(
          body: RepaintBoundary(key: key, child: page),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    if (shots != null) {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$shots/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  }

  for (final MapEntry(key: watch, value: size) in _sizes.entries) {
    testWidgets('watch pages fit on $watch', (tester) async {
      Future<void> page(String name, Widget child) =>
          show(tester, '${name}_$watch', size, child);

      var game = offlineGame();
      game.welcomed.value = true;
      game.choosingMode.value = true;
      await page('1_start', WatchLobby(game: game));

      for (final mode in GameMode.values) {
        game = offlineGame();
        game.welcomed.value = true;
        game.chooseMode(mode);
        await page('2_room_${mode.name}', WatchLobby(game: game));
      }

      game = offlineGame();
      game.welcomed.value = true;
      game.chooseMode(GameMode.multi);
      game.isHost.value = false;
      await page('3_room_guest', WatchLobby(game: game));

      game = offlineGame();
      game.aliveCount.value = 4;
      game.ammoNotifier.value = 23;
      game.hpNotifier.value = game.myMaxHp * 0.6;
      game.notice.value = 'MUNITION LEER';
      game.inventory
        ..add(PowerUpType.values.first)
        ..add(PowerUpType.values.last);
      await page('4_hud', WatchHud(game: game));

      game.respawnSeconds.value = 7;
      await page('5_hud_respawn', WatchHud(game: game));

      await page('6_countdown', WatchCountdown(game: game));

      game.outcome.value = RoundOutcome.won;
      game.roundStats
        ..kills = 7
        ..damage = 612;
      await page('7_won', WatchRoundOver(game: game));
      game.outcome.value = RoundOutcome.lost;
      await page('8_lost', WatchRoundOver(game: game));

      game.spectatingName.value = 'Panzer-4711-lang';
      await page('9_spectator', WatchSpectator(game: game));

      game.closedReason.value = 'Der Gastgeber hat den Warteraum geschlossen.';
      await page('10_closed', WatchClosed(game: game));
    });
  }

  // The lists run on below the first screen: every row on the smallest watch.
  testWidgets('long watch pages fit on the smallest watch', (tester) async {
    const tall = Size(162, 560);
    var game = offlineGame();
    game.welcomed.value = true;
    game.choosingMode.value = true;
    await show(tester, 'tall_start', tall, WatchLobby(game: game));
    for (final mode in GameMode.values) {
      game = offlineGame();
      game.welcomed.value = true;
      game.chooseMode(mode);
      await show(
        tester,
        'tall_room_${mode.name}',
        tall,
        WatchLobby(game: game),
      );
    }
    game = offlineGame();
    game.outcome.value = RoundOutcome.won;
    await show(tester, 'tall_won', tall, WatchRoundOver(game: game));
  });
}
