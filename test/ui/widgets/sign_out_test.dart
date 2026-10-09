import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/db/account_service.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/net/room.dart';
import 'package:wargame/src/ui/widgets/account_panel.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../helpers/fakes.dart';

void main() {
  late List<bool> switches;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await openLocalStore();
    switches = [];
    onRoomSwitch = (room, {required host}) => switches.add(host);
  });

  tearDown(() => onRoomSwitch = null);

  /// Opens the panel in a dialog that closes on sign-out, like the account
  /// sheet on the start page.
  Future<void> open(WidgetTester tester, AccountService accounts) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialog) => Dialog(
                child: AccountPanel(
                  accounts: accounts,
                  onSignedOut: () => Navigator.of(dialog).pop(),
                ),
              ),
            ),
            child: const Text('KONTO'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('KONTO'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountPanel), findsOneWidget);
  }

  testWidgets('signing out closes the dialog and starts over on the '
      'start page', (tester) async {
    final accounts = FakeAccounts();
    await open(tester, accounts);

    await tester.tap(find.text('ABMELDEN'));
    await tester.pumpAndSettle();

    expect(accounts.signOuts, 1);
    expect(find.byType(AccountPanel), findsNothing, reason: 'dialog open');
    expect(switches, [true], reason: 'the game has to start over');
    expect(
      needsWelcome(accounts: true, guest: accounts.isGuest),
      isFalse,
      reason: 'signed out lands on the start page, not the welcome page',
    );
  });

  testWidgets('a failed sign-out stays in the dialog and says so', (
    tester,
  ) async {
    final accounts = FakeAccounts(fails: true);
    await open(tester, accounts);

    await tester.tap(find.text('ABMELDEN'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountPanel), findsOneWidget);
    expect(find.textContaining('offline'), findsOneWidget);
    expect(switches, isEmpty);
  });

  test('everybody starts on the start page, the welcome page only follows '
      'a failed mail link', () {
    expect(needsWelcome(accounts: true, guest: true), isFalse);
    expect(
      needsWelcome(accounts: true, guest: true, mailLinkFailed: true),
      isTrue,
    );
    expect(
      needsWelcome(accounts: true, guest: false, mailLinkFailed: true),
      isFalse,
    );
    expect(
      needsWelcome(accounts: false, guest: true, mailLinkFailed: true),
      isFalse,
    );
  });
}
