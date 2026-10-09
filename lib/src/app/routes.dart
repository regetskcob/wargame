import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import '../ui/controller_view.dart';
import '../ui/widgets/room_scanner.dart';

/// Locations of the screens on top of the game. Everything inside a round
/// (lobby, HUD, results) stays a Flame overlay that follows the game phase;
/// the router only holds what covers the whole game.
abstract final class Routes {
  /// The game itself. On the web the room stays in the real query
  /// (`?room=CODE`), before the `#`, so links shared so far keep working.
  static const game = '/';

  /// The camera that reads a room's QR code and returns its code.
  static const scanRoom = '/scan/room';

  /// The camera that reads a screen's pairing code and returns it.
  static const scanPad = '/scan/pad';

  /// This device as the controller of the screen with [code]. [name] is how
  /// the phone shows up there.
  static String pad(String code, {String? name}) => Uri(
    path: '/pad/$code',
    queryParameters: name == null ? null : {'name': name},
  ).toString();
}

/// The router of the game app. [game] builds the page with the game, which
/// stays mounted below everything pushed over it, so a round goes on while
/// the camera or the controller is open.
GoRouter buildRouter({required WidgetBuilder game}) => GoRouter(
  routes: [
    GoRoute(
      path: Routes.game,
      builder: (context, _) => game(context),
      routes: [
        GoRoute(
          path: 'pad/:code',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            fullscreenDialog: true,
            child: ControllerView(
              code: state.pathParameters['code']!,
              name: state.uri.queryParameters['name'] ?? tr('Handy', 'Phone'),
            ),
          ),
        ),
        GoRoute(
          path: 'scan/:kind',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            fullscreenDialog: true,
            child: RoomScanner(pad: state.pathParameters['kind'] == 'pad'),
          ),
        ),
      ],
    ),
  ],
  // An unknown address, say an old bookmark with a stale fragment, simply
  // shows the game.
  onException: (_, _, router) => router.go(Routes.game),
);
