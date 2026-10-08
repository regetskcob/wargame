import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/src/db/account_service.dart';
import 'package:game/src/game/space_game.dart';
import 'package:game/src/net/room.dart';
import 'package:game/src/ui/widgets/account_panel.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fakes.dart';

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
      'welcome page', (tester) async {
    rememberGuest();
    final accounts = FakeAccounts();
    await open(tester, accounts);

    await tester.tap(find.text('ABMELDEN'));
    await tester.pumpAndSettle();

    expect(accounts.signOuts, 1);
    expect(find.byType(AccountPanel), findsNothing, reason: 'dialog open');
    expect(switches, [true], reason: 'the game has to start over');
    expect(prefersGuest(), isFalse, reason: 'the guest choice must go');
    expect(
      needsWelcome(
        accounts: true,
        guest: accounts.isGuest,
        prefersGuest: prefersGuest(),
      ),
      isTrue,
    );
  });

  testWidgets('a failed sign-out stays in the dialog and says so', (
    tester,
  ) async {
    rememberGuest();
    final accounts = FakeAccounts(fails: true);
    await open(tester, accounts);

    await tester.tap(find.text('ABMELDEN'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountPanel), findsOneWidget);
    expect(find.textContaining('offline'), findsOneWidget);
    expect(switches, isEmpty);
    expect(prefersGuest(), isTrue);
  });

  test('the welcome page asks only signed-out players who did not pick the '
      'guest', () {
    expect(
      needsWelcome(accounts: true, guest: true, prefersGuest: false),
      isTrue,
    );
    expect(
      needsWelcome(accounts: true, guest: true, prefersGuest: true),
      isFalse,
    );
    expect(
      needsWelcome(
        accounts: true,
        guest: true,
        prefersGuest: true,
        mailLinkFailed: true,
      ),
      isTrue,
    );
    expect(
      needsWelcome(accounts: true, guest: false, prefersGuest: false),
      isFalse,
    );
    expect(
      needsWelcome(accounts: false, guest: true, prefersGuest: false),
      isFalse,
    );
  });
}
