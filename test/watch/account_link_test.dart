import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wargame/src/game/round_stats.dart';
import 'package:wargame/src/watch/account_link.dart';
import 'package:wargame/src/watch/linked_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    AccountLink.instance.take(const {'token': null});
  });

  Map<String, Object?> lent({Duration lasts = const Duration(hours: 1)}) => {
    'user': 'acc-1',
    'name': 'Darwin',
    'token': 'jwt',
    'expires': clock.now().add(lasts).millisecondsSinceEpoch,
  };

  test('the watch takes the account the phone lends, and gives it back', () {
    final link = AccountLink.instance;
    link.take(lent());
    expect(link.account.value?.userId, 'acc-1');
    expect(link.account.value?.name, 'Darwin');
    expect(link.account.value?.usable, isTrue);
    // A guest or a signed out phone lends nothing.
    link.take(const {'token': null});
    expect(link.account.value, isNull);
    // Other messages leave the account alone.
    link.take(lent());
    link.take(const {'something': 'else'});
    expect(link.account.value, isNotNull);
  });

  test('an access token about to run out is no longer used', () {
    final account = LinkedAccount.tryParse(lent(lasts: Duration.zero));
    expect(account!.usable, isFalse);
    expect(LinkedAccount.tryParse({'user': 'x', 'token': ''}), isNull);
    expect(LinkedAccount.tryParse('nonsense'), isNull);
  });

  test('a round without a usable token waits and is not lost', () async {
    final pending = PendingRounds();
    // A connection without auth of its own, like the watch's linked one.
    final client = SupabaseClient(
      'http://localhost:1',
      'key',
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      accessToken: () async => null,
    );
    final scores = LinkedScores(
      AccountLink.instance,
      client,
      client,
      pending: pending,
    );
    expect(scores.isGuest, isTrue);
    AccountLink.instance.take(lent(lasts: Duration.zero));
    expect(scores.isGuest, isFalse, reason: 'ranked, just not sent yet');
    expect(scores.myId, 'acc-1');
    final record = await scores.recordRound(
      name: 'Darwin',
      stats: RoundStats()..kills = 2,
      won: true,
      tankType: 1,
    );
    expect(record, isNull);
    expect(await pending.length, 1);
    expect((await pending.first())!['p_kills'], 2);
  });

  test('the queue keeps the latest rounds up to its limit', () async {
    final pending = PendingRounds();
    for (var i = 0; i < PendingRounds.limit + 5; i++) {
      await pending.add({'n': i});
    }
    expect(await pending.length, PendingRounds.limit);
    expect((await pending.first())!['n'], 5);
    await pending.removeFirst();
    expect((await pending.first())!['n'], 6);
  });
}
