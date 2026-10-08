import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kPrimaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../db/account_service.dart';
import '../db/online_service.dart';
import '../db/profile_service.dart';
import '../db/score_service.dart';
import '../game/game_phase.dart';
import '../game/tank_game.dart';
import '../l10n/l10n.dart';
import '../net/net_service.dart';
import '../net/pad_link.dart';
import '../net/room.dart';
import '../ui/theme.dart';
import '../ui/closed_overlay.dart';
import '../ui/controller_view.dart';
import '../ui/countdown_overlay.dart';
import '../ui/hud_overlay.dart';
import '../ui/lobby_overlay.dart';
import '../ui/round_over_overlay.dart';
import '../ui/spectator_overlay.dart';
import '../ui/tutorial/tutorial_overlay.dart';
import '../tv/second_player.dart';
import '../tv/split_view.dart';
import '../tv/tv_focus_frame.dart';
import '../tv/tv_input.dart';
import '../ui/widgets/tablet_scale.dart';
import '../watch/watch_lobby.dart';
import '../watch/watch_overlays.dart';
import '../watch/watch_support.dart';
import 'live_activity.dart';
import 'overlay_ids.dart';

class GameApp extends StatefulWidget {
  const GameApp({super.key});

  @override
  State<GameApp> createState() => _GameAppState();
}

class _GameAppState extends State<GameApp> {
  late TankGame game;
  late LiveActivityBridge _liveActivity;
  final _gameFocus = FocusNode(debugLabel: 'game');
  final _navigator = GlobalKey<NavigatorState>();
  late final _online = OnlineService(
    Supabase.instance.client,
    inMatch: () => game.phase.value != GamePhase.lobby,
  );

  @override
  void initState() {
    super.initState();
    game = _createGame(resolveRoom(), host: isRoomHost());
    _liveActivity = LiveActivityBridge(game)..attach();
    _online.start();
    onRoomSwitch = _switchRoom;
    onPadLink = _openPad;
    listenForRoomLinks();
    PadScreen.instance.game = game;
    unawaited(PadScreen.instance.resume());
    _second?.attach();
  }

  /// A second player on the Apple TV, with a game of their own.
  late final SecondPlayer? _second = padsSupported
      ? SecondPlayer(() => game)
      : null;

  /// Between rounds the second player may come or go.
  void _phaseChanged() => _second?.update();

  /// A pairing link opened on this device: it becomes the controller of
  /// the screen that showed it.
  void _openPad(String text) {
    final code = padCodeFrom(text);
    final navigator = _navigator.currentState;
    if (code == null) {
      return;
    }
    if (navigator == null) {
      // A link that started the app can come in before the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _navigator.currentState != null) {
          _openPad(code);
        }
      });
      return;
    }
    unawaited(
      navigator.push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => ControllerView(code: code, name: game.myName),
        ),
      ),
    );
  }

  TankGame _createGame(String room, {required bool host}) {
    final client = Supabase.instance.client;
    final random = Random();
    final myId = [
      for (var i = 0; i < 16; i++) random.nextInt(16).toRadixString(16),
    ].join();
    return TankGame(
        net: NetService(myId: myId, room: room, isHost: host),
        myId: myId,
        scoreService: ScoreService(client),
        profiles: ProfileService(client),
        accounts: AccountService(client),
      )
      ..phase.addListener(_reclaimFocus)
      ..phase.addListener(_phaseChanged)
      // Somebody from another device came or went: the second player may
      // need a connection of their own, or no longer.
      ..roster.addListener(_phaseChanged);
  }

  /// The apps' stand-in for loading another room's address: the old game
  /// leaves its room and a fresh one joins the new room.
  void _switchRoom(String room, {required bool host}) {
    final old = game;
    old.phase
      ..removeListener(_reclaimFocus)
      ..removeListener(_phaseChanged);
    old.roster.removeListener(_phaseChanged);
    _liveActivity.detach();
    unawaited(old.leave());
    setState(() => game = _createGame(room, host: host));
    PadScreen.instance.game = game;
    _liveActivity = LiveActivityBridge(game)..attach();
    _second?.followRoom();
  }

  // The lobby's text field and buttons own the keyboard focus. Once their
  // overlay is removed, nothing hands it back to the game, so key presses
  // never reach the tank.
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
    onRoomSwitch = null;
    onPadLink = null;
    _online.dispose();
    _liveActivity.detach();
    game.phase
      ..removeListener(_reclaimFocus)
      ..removeListener(_phaseChanged);
    game.roster.removeListener(_phaseChanged);
    _second?.dispose();
    _gameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
      valueListenable: L10n.lang,
      builder: (context, lang, _) => _app(lang),
    );
  }

  Widget _app(AppLang lang) {
    return MaterialApp(
      navigatorKey: _navigator,
      title: 'Panzergefecht',
      locale: lang.locale,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: [for (final l in AppLang.values) l.locale],
      debugShowCheckedModeBanner: false,
      theme: buildBundeswehrTheme(),
      // Seen from the sofa: everything a good deal larger.
      builder: onTv
          ? (context, child) => TvFocusFrame(
              holdFocus: () =>
                  game.phase.value == GamePhase.countdown ||
                  game.phase.value == GamePhase.playing,
              // Up and down walk the menus in reading order, so a swipe
              // never skips a button that is not straight below. Set in
              // here, below the text editing keys, so a text field lets go
              // of them too.
              child: Shortcuts(
                shortcuts: const {
                  SingleActivator(LogicalKeyboardKey.arrowDown):
                      NextFocusIntent(),
                  SingleActivator(LogicalKeyboardKey.arrowUp):
                      PreviousFocusIntent(),
                },
                child: FixedScale(scale: tvScale, child: child!),
              ),
            )
          : null,
      home: onTv ? _TvBack(game: game, child: _home()) : _home(),
    );
  }

  Widget _home() {
    final second = _second;
    final view = _view();
    return Scaffold(
      backgroundColor: BwColors.background,
      body: second == null
          ? view
          : TvSplitView(host: game, second: second, child: view),
    );
  }

  Widget _view() {
    return Listener(
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
          if (event.buttons & kPrimaryMouseButton != 0 && !game.pointerOnHud) {
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
        child: GameWidget<TankGame>(
          // A new room brings a new game, which needs a fresh widget.
          key: ObjectKey(game),
          game: game,
          focusNode: _gameFocus,
          autofocus: true,
          overlayBuilderMap: onWatch
              ? {
                  OverlayIds.lobby: (context, game) => WatchLobby(game: game),
                  OverlayIds.countdown: (context, game) =>
                      WatchCountdown(game: game),
                  OverlayIds.hud: (context, game) => WatchHud(game: game),
                  OverlayIds.spectator: (context, game) =>
                      WatchSpectator(game: game),
                  OverlayIds.roundOver: (context, game) =>
                      WatchRoundOver(game: game),
                  OverlayIds.closed: (context, game) => WatchClosed(game: game),
                  OverlayIds.tutorial: (context, game) =>
                      const SizedBox.shrink(),
                }
              : {
                  OverlayIds.lobby: (context, game) => LobbyOverlay(game: game),
                  OverlayIds.countdown: (context, game) =>
                      CountdownOverlay(game: game),
                  OverlayIds.hud: (context, game) =>
                      TabletScale(child: HudOverlay(game: game)),
                  OverlayIds.spectator: (context, game) =>
                      SpectatorOverlay(game: game),
                  OverlayIds.roundOver: (context, game) =>
                      RoundOverOverlay(game: game),
                  OverlayIds.closed: (context, game) =>
                      ClosedOverlay(game: game),
                  OverlayIds.tutorial: (context, game) =>
                      // On the Apple TV the controls follow the controller
                      // in hand.
                      ListenableBuilder(
                        listenable: Listenable.merge([
                          game.touchMode,
                          TvInput.instance.kind,
                        ]),
                        builder: (context, _) => TutorialOverlay(
                          touch: game.touchMode.value,
                          onClose: game.closeTutorial,
                        ),
                      ),
                },
        ),
      ),
    );
  }
}

/// The Menu button of the Siri Remote, and B on a controller, step back
/// through the menus and leave the app only from the start page, as tvOS
/// expects. In a round they do nothing.
class _TvBack extends StatelessWidget {
  const _TvBack({required this.game, required this.child});

  final TankGame game;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !tvBack(game)) {
          unawaited(SystemNavigator.pop());
        }
      },
      child: child,
    );
  }
}

/// The browser on a phone that opened a pairing link without the app: the
/// page is the controller of that screen and nothing else.
class ControllerApp extends StatelessWidget {
  const ControllerApp({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
      valueListenable: L10n.lang,
      builder: (context, lang, _) => MaterialApp(
        title: 'Panzergefecht',
        locale: lang.locale,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: [for (final l in AppLang.values) l.locale],
        debugShowCheckedModeBanner: false,
        theme: buildBundeswehrTheme(),
        home: ControllerView(
          code: code,
          name: tr('Handy', 'Phone'),
          onClose: leavePadPage,
        ),
      ),
    );
  }
}
