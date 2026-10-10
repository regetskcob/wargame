import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/ui/widgets/account_panel.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('with a call sign field above, registering asks for no '
      'second name and says which one it takes', (tester) async {
    final accounts = FakeAccounts();
    await accounts.signOut(); // Back to a guest.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountPanel(
            accounts: accounts,
            callSign: 'Testfuchs',
            callSignAbove: () => 'Testfuchs',
            initiallyOpen: true,
          ),
        ),
      ),
    );
    expect(find.widgetWithText(TextField, 'RUFNAME'), findsNothing);
    expect(
      find.textContaining('Du registrierst dich als Testfuchs'),
      findsOneWidget,
    );
  });

  testWidgets('without one, as on the welcome page, it asks for the name', (
    tester,
  ) async {
    final accounts = FakeAccounts();
    await accounts.signOut();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountPanel(accounts: accounts, initiallyOpen: true),
        ),
      ),
    );
    expect(find.widgetWithText(TextField, 'RUFNAME'), findsOneWidget);
  });
}
