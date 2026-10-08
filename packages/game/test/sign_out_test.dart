import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/src/db/account_service.dart';
import 'package:game/src/game/space_game.dart';
import 'package:game/src/net/room.dart';
import 'package:game/src/ui/widgets/account_panel.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User _user({required bool guest}) => User(
  id: guest ? 'guest' : 'account',
  audience: 'authenticated',
  createdAt: DateTime.utc(2026, 10, 8),
  email: guest ? null : 'peter@example.com',
  isAnonymous: guest,
);

/// Stands in for Supabase: signed into an account, signing out leaves a
/// fresh guest behind, or fails when told to.
class _FakeAccounts implements AccountService {
  _FakeAccounts({this.fails = false});

  final bool fails;
  var signOuts = 0;

  @override
  final user = ValueNotifier<User?>(_user(guest: false));

  @override
  final providers = ValueNotifier<List<(OAuthProvider, String)>>(const []);

  @override
  Future<void> loadProviders() async {}

  @override
  bool get isGuest => user.value?.isAnonymous ?? true;

  @override
  String? get email => user.value?.email;

  @override
  Future<void> signOut() async {
    signOuts++;
    if (fails) {
      throw Exception('offline');
    }
    user.value = _user(guest: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
    final accounts = _FakeAccounts();
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
    final accounts = _FakeAccounts(fails: true);
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
