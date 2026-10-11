// Round tickets (migration 0019) against a running local Supabase stack.
// Start it first with `supabase start` from the repository root. CI has no
// stack and leaves it out with `--exclude-tags supabase`.

@Tags(['supabase'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wargame/src/db/score_service.dart';
import 'package:wargame/src/game/round_stats.dart';

const _url = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'http://127.0.0.1:54621',
);
const _key = String.fromEnvironment(
  'SUPABASE_KEY',
  defaultValue: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
);

/// The gap `record_round` asks for between two rounds of one pilot.
const _gap = Duration(seconds: 9);

void main() {
  final clients = <SupabaseClient>[];

  /// A fresh account on the local stack, which confirms e-mail addresses
  /// without sending anything.
  Future<ScoreService> account() async {
    final client = SupabaseClient(
      _url,
      _key,
      authOptions: AuthClientOptions(asyncStorage: MemoryAuthAsyncStorage()),
    );
    clients.add(client);
    final random = Random.secure();
    final tag = List.generate(12, (_) => random.nextInt(36).toRadixString(36));
    await client.auth.signUp(
      email: 'ticket-${tag.join()}@example.test',
      password: 'pw-${tag.reversed.join()}',
    );
    return ScoreService(client);
  }

  tearDownAll(() async {
    for (final client in clients) {
      await client.dispose();
    }
  });

  /// A won round against two CPU tanks with one kill and 100 damage.
  Map<String, dynamic> round(String? ticket) => ScoreService.roundParams(
    name: 'Ticket',
    stats: RoundStats()
      ..kills = 1
      ..damage = 100
      ..survived = 30,
    won: true,
    tankType: 0,
    cpuBeaten: 2,
    ticket: ticket,
  );

  test('a round with its ticket counts in full, once; without one the CPU '
      'tanks and the win count for nothing', () async {
    final a = await account();
    final b = await account();

    final ticket = await a.startRound(cpu: 2);
    expect(ticket, isNotNull);
    // Rounds under five seconds earn only the ten points for taking part,
    // and a CPU tank counts for every five seconds at most.
    await Future<void>.delayed(const Duration(seconds: 11));
    final full = await a.submit(round(ticket));
    // 10 + 20 for the kill + 50 for the win + 10 for the damage + 20 for
    // the two CPU tanks outlasted.
    expect(full.xpGained, 110);
    expect(full.ratingChange, greaterThan(0));

    await Future<void>.delayed(_gap);
    await expectLater(
      a.submit(round(ticket)),
      throwsA(isA<PostgrestApiException>()),
      reason: 'a ticket counts once',
    );

    // Somebody else's ticket is as good as none.
    final foreign = await a.startRound(cpu: 2);
    final borrowed = await b.submit(round(foreign));
    expect(borrowed.xpGained, 40, reason: '10 + 20 + 10, no win, no CPU');
    expect(borrowed.ratingChange, 0);

    await Future<void>.delayed(_gap);
    final bare = await b.submit(round(null));
    expect(bare.xpGained, lessThanOrEqualTo(40));
    expect(bare.ratingChange, 0);
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('guests get no ticket', () async {
    final client = SupabaseClient(
      _url,
      _key,
      authOptions: AuthClientOptions(asyncStorage: MemoryAuthAsyncStorage()),
    );
    clients.add(client);
    await client.auth.signInAnonymously();
    expect(await ScoreService(client).startRound(cpu: 4), isNull);
  });
}
