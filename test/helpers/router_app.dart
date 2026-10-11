import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/app/routes.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/ui/account_page.dart';
import 'package:wargame/src/ui/widgets/language_rebuild.dart';

/// [home] as the game's page of the app's router, with the account page
/// of [game] over it, as `GameApp` builds them.
Future<void> pumpRouterApp(
  WidgetTester tester,
  TankGame game,
  Widget home,
) async {
  final router = buildRouter(
    game: (_) => Scaffold(body: home),
    account: (_) => AccountPage(game: game),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => LanguageRebuild(child: child!),
    ),
  );
}
