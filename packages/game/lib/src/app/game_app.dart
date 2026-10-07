import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kPrimaryMouseButton;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../db/score_service.dart';
import '../game/game_phase.dart';
import '../game/space_game.dart';
import '../net/net_service.dart';
import '../net/room.dart';
import '../theme.dart';
import '../ui/closed_overlay.dart';
import '../ui/countdown_overlay.dart';
import '../ui/hud_overlay.dart';
import '../ui/lobby_overlay.dart';
import '../ui/round_over_overlay.dart';
import '../ui/spectator_overlay.dart';
import 'overlay_ids.dart';

class GameApp extends StatefulWidget {
  const GameApp({super.key});

  @override
  State<GameApp> createState() => _GameAppState();
}

class _GameAppState extends State<GameApp> {
  late final SpaceGame game;
  final _gameFocus = FocusNode(debugLabel: 'game');

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    final random = Random();
    final myId = [
      for (var i = 0; i < 16; i++) random.nextInt(16).toRadixString(16),
    ].join();
    game = SpaceGame(
      net: NetService(myId: myId, room: resolveRoom(), isHost: isRoomHost()),
      myId: myId,
      scoreService: ScoreService(client),
    );
    game.phase.addListener(_reclaimFocus);
  }

  // The lobby's text field and buttons own the keyboard focus. Once their
  // overlay is removed, nothing hands it back to the game, so key presses
  // never reach the ship.
  void _reclaimFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _gameFocus.requestFocus();
      }
    });
  }

  void _aimWithMouse(Offset position) {
    game.pointer = Vector2(position.dx, position.dy);
  }

  @override
  void dispose() {
    game.phase.removeListener(_reclaimFocus);
    _gameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panzergefecht',
      debugShowCheckedModeBanner: false,
      theme: buildBundeswehrTheme(),
      home: Scaffold(
        backgroundColor: BwColors.background,
        body: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            // A click on a button must not take the keyboard from the tank.
            if (game.phase.value != GamePhase.lobby) {
              _reclaimFocus();
            }
            if (event.kind == PointerDeviceKind.touch) {
              game.touchMode.value = true;
            } else if (event.kind == PointerDeviceKind.mouse) {
              _aimWithMouse(event.localPosition);
              if (event.buttons & kPrimaryMouseButton != 0) {
                game.touch.fire = true;
              }
            }
          },
          onPointerUp: (event) {
            if (event.kind == PointerDeviceKind.mouse) {
              game.touch.fire = false;
            }
          },
          onPointerCancel: (_) => game.touch.fire = false,
          onPointerMove: (event) {
            if (event.kind == PointerDeviceKind.mouse) {
              _aimWithMouse(event.localPosition);
            }
          },
          onPointerHover: (event) => _aimWithMouse(event.localPosition),
          child: ValueListenableBuilder<GamePhase>(
            valueListenable: game.phase,
            builder: (context, phase, child) => MouseRegion(
              cursor: phase == GamePhase.playing
                  ? SystemMouseCursors.precise
                  : MouseCursor.defer,
              onExit: (_) => game.touch.fire = false,
              child: child,
            ),
            child: GameWidget<SpaceGame>(
              game: game,
              focusNode: _gameFocus,
              autofocus: true,
              overlayBuilderMap: {
                OverlayIds.lobby: (context, game) => LobbyOverlay(game: game),
                OverlayIds.countdown: (context, game) =>
                    CountdownOverlay(game: game),
                OverlayIds.hud: (context, game) => HudOverlay(game: game),
                OverlayIds.spectator: (context, game) =>
                    SpectatorOverlay(game: game),
                OverlayIds.roundOver: (context, game) =>
                    RoundOverOverlay(game: game),
                OverlayIds.closed: (context, game) => ClosedOverlay(game: game),
              },
            ),
          ),
        ),
      ),
    );
  }
}
