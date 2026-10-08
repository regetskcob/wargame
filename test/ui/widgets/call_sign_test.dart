import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/ui/widgets/account_sheet.dart';
import 'package:wargame/src/ui/widgets/call_sign.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('the call sign is changed in the account sheet, the page '
      'behind only shows it', (tester) async {
    final profiles = FakeProfiles();
    final game = offlineGame(profiles: profiles)..myName = 'Panzer-1234';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              CallSign(game: game),
              AccountButton(game: game),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Panzer-1234'), findsOneWidget);

    await tester.tap(find.byType(AccountButton));
    await tester.pumpAndSettle();
    final field = find.widgetWithText(TextField, 'RUFNAME');
    expect(field, findsOneWidget);

    await tester.enterText(field, 'Peter Maffay');
    await tester.pump();
    expect(game.myName, 'Peter Maffay');
    expect(
      find.descendant(
        of: find.byType(CallSign),
        matching: find.text('Peter Maffay'),
      ),
      findsOneWidget,
    );

    // An empty field keeps the last name.
    await tester.enterText(field, '  ');
    await tester.pump();
    expect(game.myName, 'Peter Maffay');

    // Saved once the typing settled.
    await tester.pump(const Duration(seconds: 1));
    expect(profiles.saved.last, 'Peter Maffay');

    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();
    expect(find.text('Peter Maffay'), findsOneWidget);
  });

  testWidgets('a name loaded after signing in shows up in the sheet', (
    tester,
  ) async {
    final game = offlineGame()..myName = 'Panzer-1234';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AccountButton(game: game)),
      ),
    );
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
}
