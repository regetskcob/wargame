import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/ui/account_page.dart';
import 'package:wargame/src/ui/widgets/call_sign.dart';

import '../../helpers/fakes.dart';
import '../../helpers/router_app.dart';

void main() {
  testWidgets('the call sign is saved in the account page with the tick or '
      'Enter, the page behind only shows it', (tester) async {
    final profiles = FakeProfiles();
    final game = offlineGame(profiles: profiles)..myName = 'Panzer-1234';
    await pumpRouterApp(
      tester,
      game,
      Column(
        children: [
          CallSign(game: game),
          AccountButton(game: game),
        ],
      ),
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Panzer-1234'), findsOneWidget);

    await tester.tap(find.byType(AccountButton));
    await tester.pumpAndSettle();
    final field = find.widgetWithText(TextField, 'RUFNAME');
    expect(field, findsOneWidget);

    // Typing alone changes nothing yet, the tick takes the name.
    await tester.enterText(field, 'Peter Maffay');
    await tester.pump();
    expect(game.myName, 'Panzer-1234');
    expect(find.text('Mit dem Haken oder Enter speichern'), findsOneWidget);

    await tester.tap(find.byTooltip('Rufnamen speichern'));
    await tester.pump();
    expect(game.myName, 'Peter Maffay');
    expect(find.text('Gespeichert'), findsOneWidget);
    expect(
      // The page behind lies offstage under the account page.
      find.descendant(
        of: find.byType(CallSign, skipOffstage: false),
        matching: find.text('Peter Maffay', skipOffstage: false),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(profiles.saved.last, 'Peter Maffay');

    // An empty field cannot be saved and keeps the last name.
    await tester.enterText(field, '  ');
    await tester.pump();
    expect(find.text('Gespeichert'), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(game.myName, 'Peter Maffay');

    // Enter saves as well.
    await tester.enterText(field, 'Udo');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(game.myName, 'Udo');
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();
    expect(find.text('Udo'), findsOneWidget);
  });

  testWidgets('a name loaded after signing in shows up on the page', (
    tester,
  ) async {
    final game = offlineGame()..myName = 'Panzer-1234';
    await pumpRouterApp(tester, game, AccountButton(game: game));
    await tester.tap(find.byType(AccountButton));
    await tester.pumpAndSettle();

    game.myName = 'Peter Maffay';
    game.pilotVersion.value++;
    await tester.pump();
    expect(
      find.descendant(
        of: find.widgetWithText(TextField, 'RUFNAME'),
        matching: find.text('Peter Maffay'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('closing the page while typing lets go of the keyboard', (
    tester,
  ) async {
    final game = offlineGame()..myName = 'Panzer-1234';
    await pumpRouterApp(tester, game, AccountButton(game: game));
    await tester.tap(find.byType(AccountButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextField, 'RUFNAME'));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
  });
}
