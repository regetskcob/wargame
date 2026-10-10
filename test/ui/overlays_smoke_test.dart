// Whole rounds take a few seconds each, many more on a busy machine:
// they get more than the default 30 s before they count as hung.
@Timeout(Duration(minutes: 3))
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:wargame/src/app/overlay_ids.dart';
import 'package:wargame/src/game/bot_level.dart';
import 'package:wargame/src/game/components/power_up.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/kill_feed.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/l10n/l10n.dart';
import 'package:wargame/src/net/room.dart';
import 'package:wargame/src/ui/closed_overlay.dart';
import 'package:wargame/src/ui/countdown_overlay.dart';
import 'package:wargame/src/ui/hud_overlay.dart';
import 'package:wargame/src/ui/lobby_overlay.dart';
import 'package:wargame/src/ui/round_over_overlay.dart';
import 'package:wargame/src/ui/spectator_overlay.dart';
import 'package:wargame/src/ui/theme.dart';
import 'package:wargame/src/ui/welcome_view.dart';
import 'package:wargame/src/ui/widgets/tablet_scale.dart';

import '../helpers/fakes.dart';

// Smoke tests for the overlays on top of the game: each one is built from
// a real game in the phase it belongs to, on a desktop and a phone, in
// German and English, and must lay out without an overflow or an error.
// They do not check what the overlays say; that is for focused tests.

/// The overlays of the app, as `GameApp` builds them outside the TV and
/// the watch.
Widget _overlay(String id, TankGame game) => switch (id) {
  OverlayIds.lobby => LobbyOverlay(game: game),
  OverlayIds.countdown => CountdownOverlay(game: game),
  OverlayIds.hud => TabletScale(child: HudOverlay(game: game)),
  OverlayIds.spectator => SpectatorOverlay(game: game),
  OverlayIds.roundOver => RoundOverOverlay(game: game),
  OverlayIds.closed => ClosedOverlay(game: game),
  _ => const SizedBox.shrink(),
};

const _screens = {'desktop': Size(1280, 720), 'phone': Size(844, 390)};

/// Shows what the game has open right now, as the GameWidget would.
Future<void> _show(WidgetTester tester, TankGame game, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  await tester.pumpWidget(
    ValueListenableBuilder<AppLang>(
      valueListenable: L10n.lang,
      builder: (context, lang, _) => MaterialApp(
        locale: lang.locale,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: [for (final l in AppLang.values) l.locale],
        theme: buildGameTheme(),
        home: Scaffold(
          backgroundColor: GameColors.background,
          body: ListenableBuilder(
            listenable: game.phase,
            builder: (context, _) => Stack(
              fit: StackFit.expand,
              children: [
                for (final id in game.overlays.activeOverlays)
                  _overlay(id, game),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  // Long enough for entry animations, short of a repeating one settling.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// Plays [seconds] of the round outside the fake clock of the test, so
/// the round's own timers and tanks loading in run as in the app.
Future<void> _play(WidgetTester tester, TankGame game, double seconds) =>
    tester.runAsync(() async {
      const dt = 1 / 30;
      for (var frame = 0; frame < seconds / dt; frame++) {
        game.touch
          ..thrust = true
          ..fire = frame.isEven;
        game.update(dt);
        await Future<void>.delayed(Duration.zero);
      }
    });

/// Changes the game outside the fake clock, so timers it starts run as in
/// the app.
Future<void> _act(WidgetTester tester, void Function() change) =>
    tester.runAsync(() async => change());

/// A page of its own, as the router shows it.
Future<void> _page(WidgetTester tester, Widget page, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildGameTheme(),
      home: Scaffold(backgroundColor: GameColors.background, body: page),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpWidget(const SizedBox());
}

Future<TankGame> _game(WidgetTester tester) async {
  final game = await tester.runAsync(
    () => loadedGame(net: FakeNet()..othersPresent = true),
  );
  return game!;
}

Future<void> _start(WidgetTester tester, TankGame game, GameMode mode) async {
  await _act(tester, () => _startNow(game, mode));
  await _play(tester, game, 0.2);
}

void _startNow(TankGame game, GameMode mode) {
  game
    ..chooseMode(mode)
    ..fillWithBots.value = true;
  final now = DateTime.now().millisecondsSinceEpoch;
  game.startRound(
    startedAt: mode == GameMode.defense
        ? now - GameConfig.firstWaveSeconds * 1000
        : now - 1,
  );
}

/// The game's own font instead of the test font, whose square glyphs are
/// far wider: an overflow here is one a player would see.
Future<void> _loadFonts() async {
  final roboto = FontLoader('Roboto');
  for (final weight in ['Regular', 'Medium', 'Bold', 'Black']) {
    roboto.addFont(rootBundle.load('assets/fonts/Roboto-$weight.ttf'));
  }
  await roboto.load();
}

void main() {
  setUpAll(_loadFonts);

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await openLocalStore();
  });

  tearDown(() => L10n.lang.value = AppLang.de);

  for (final lang in AppLang.values) {
    for (final MapEntry(key: screen, value: size) in _screens.entries) {
      final where = '${lang.code}, $screen';

      testWidgets('every page of the waiting room lays out ($where)', (
        tester,
      ) async {
        L10n.lang.value = lang;
        addTearDown(tester.view.reset);
        final game = await _game(tester);
        expect(game.overlays.isActive(OverlayIds.lobby), isTrue);
        // The start page for a guest who has not chosen yet.
        game.welcomed.value = false;
        await _show(tester, game, size);
        expect(find.byType(WelcomeView), findsOneWidget);
        game.welcomed.value = true;
        // Choosing the mode, its settings, then the room of each mode.
        game.choosingMode.value = true;
        await _show(tester, game, size);
        game
          ..choosingMode.value = false
          ..configuring.value = true;
        await _show(tester, game, size);
        game.configuring.value = false;
        for (final mode in GameMode.values) {
          game.chooseMode(mode);
          await _show(tester, game, size);
          expect(find.byType(LobbyOverlay), findsOneWidget, reason: '$mode');
        }
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('the countdown lays out ($where)', (tester) async {
        L10n.lang.value = lang;
        addTearDown(tester.view.reset);
        final game = await _game(tester);
        await _act(
          tester,
          () => game
            ..chooseMode(GameMode.solo)
            ..startRound(),
        );
        expect(game.phase.value, GamePhase.countdown);
        await _show(tester, game, size);
        expect(find.byType(CountdownOverlay), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });

      for (final mode in [GameMode.solo, GameMode.defense, GameMode.flag]) {
        testWidgets('the HUD of ${mode.name} and what follows a death lay '
            'out ($where)', (tester) async {
          L10n.lang.value = lang;
          addTearDown(tester.view.reset);
          final game = await _game(tester);
          await _start(tester, game, mode);
          expect(game.phase.value, GamePhase.playing);
          await _show(tester, game, size);
          expect(find.byType(HudOverlay), findsOneWidget);
          await _play(tester, game, 3);
          // A full inventory, with touch controls and with keyboard and
          // mouse.
          for (final type in PowerUpType.values.take(4)) {
            game.inventory.add(type);
          }
          for (final touch in [true, false]) {
            game.touchMode.value = touch;
            await _show(tester, game, size);
            expect(find.byType(HudOverlay), findsOneWidget, reason: '$touch');
          }

          // A battle goes on without this player, defense and flag bring
          // the tank back after a while.
          await _act(tester, () => game.onLocalDeath(null));
          await _show(tester, game, size);
          if (game.phase.value == GamePhase.spectating) {
            expect(find.byType(SpectatorOverlay), findsOneWidget);
            await _act(tester, game.leaveRound);
            await _show(tester, game, size);
          }
          await tester.pumpWidget(const SizedBox());
        });
      }

      testWidgets('a full kill feed fits into the keyboard HUD ($where)', (
        tester,
      ) async {
        L10n.lang.value = lang;
        addTearDown(tester.view.reset);
        final game = await _game(tester);
        await _act(tester, () => game.botLevel.value = BotLevel.hard);
        await _start(tester, game, GameMode.flag);
        game
          ..touchMode.value = false
          // The feed keeps six lines, see _recordKill.
          ..killFeed.value = [
            for (var i = 0; i < 6; i++)
              KillEntry(
                victim: 'PANZER $i',
                victimTeam: 1 + i % 2,
                killer: 'PANZER ${i + 1}',
                killerTeam: 2 - i % 2,
                byMe: i == 0,
                meDied: false,
                at: DateTime.now(),
              ),
          ];
        await _show(tester, game, size);
        expect(find.byType(HudOverlay), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('the end of a battle lays out ($where)', (tester) async {
        L10n.lang.value = lang;
        addTearDown(tester.view.reset);
        final game = await _game(tester);
        // Alone and without CPU tanks a battle ends with this tank.
        await _act(tester, () {
          game
            ..fillWithBots.value = false
            ..chooseMode(GameMode.multi)
            ..startRound(startedAt: DateTime.now().millisecondsSinceEpoch - 1);
        });
        await _play(tester, game, 0.5);
        await _act(tester, () => game.onLocalDeath(null));
        await _play(tester, game, 0.5);
        expect(game.phase.value, GamePhase.roundOver);
        await _show(tester, game, size);
        expect(find.byType(RoundOverOverlay), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('a closed room lays out ($where)', (tester) async {
        L10n.lang.value = lang;
        addTearDown(tester.view.reset);
        final game = await _game(tester);
        await _page(tester, ClosedOverlay(game: game), size);
      });
    }
  }
}
