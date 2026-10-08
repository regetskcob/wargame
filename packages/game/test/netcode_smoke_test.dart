// Integration smoke test against a running local Supabase stack.
// Start it first with `supabase start` from the repository root. CI has no
// stack and leaves it out with `--exclude-tags supabase`.

// ignore_for_file: experimental_member_use

@Tags(['supabase'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:game/src/db/supabase_schema.g.dart';
import 'package:supabase/supabase.dart';

const _url = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'http://127.0.0.1:54621',
);
const _key = String.fromEnvironment(
  'SUPABASE_KEY',
  defaultValue: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
);

void main() {
  late SupabaseClient clientA;
  late SupabaseClient clientB;

  setUpAll(() async {
    final options = AuthClientOptions(asyncStorage: MemoryAuthAsyncStorage());
    clientA = SupabaseClient(_url, _key, authOptions: options);
    clientB = SupabaseClient(_url, _key, authOptions: options);
    await clientA.auth.signInAnonymously();
    await clientB.auth.signInAnonymously();
  });

  tearDownAll(() async {
    await clientA.dispose();
    await clientB.dispose();
  });

  test('broadcast and presence flow between two clients', () async {
    final idA = clientA.auth.currentUser!.id;
    final idB = clientB.auth.currentUser!.id;

    final channelA = clientA.channel(
      'game-arena-smoke',
      options: const RealtimeChannelConfig(self: false),
    );
    final channelB = clientB.channel(
      'game-arena-smoke',
      options: const RealtimeChannelConfig(self: false),
    );

    final stateSeenByB = Completer<Map<String, dynamic>>();
    channelB.onBroadcast(event: 'state').listen((payload) {
      if (!stateSeenByB.isCompleted) {
        stateSeenByB.complete(payload);
      }
    });

    final bothPresent = Completer<void>();
    channelA.onPresenceSync.listen((_) {
      final ids = {
        for (final state in channelA.presenceState())
          for (final presence in state.presences) presence.payload['id'],
      };
      if (ids.containsAll({idA, idB}) && !bothPresent.isCompleted) {
        bothPresent.complete();
      }
    });

    final subscribedA = Completer<void>();
    channelA.onStatusChange.listen((change) async {
      if (change.status == RealtimeSubscribeStatus.subscribed) {
        await channelA.track({'id': idA, 'name': 'A'});
        if (!subscribedA.isCompleted) {
          subscribedA.complete();
        }
      }
    });
    final subscribedB = Completer<void>();
    channelB.onStatusChange.listen((change) async {
      if (change.status == RealtimeSubscribeStatus.subscribed) {
        await channelB.track({'id': idB, 'name': 'B'});
        if (!subscribedB.isCompleted) {
          subscribedB.complete();
        }
      }
    });

    channelA.subscribe();
    channelB.subscribe();
    await subscribedA.future.timeout(const Duration(seconds: 30));
    await subscribedB.future.timeout(const Duration(seconds: 30));

    await bothPresent.future.timeout(const Duration(seconds: 30));

    await channelA.sendBroadcastMessage(
      event: 'state',
      payload: {'id': idA, 'x': 1.0, 'y': 2.0},
    );
    final received = await stateSeenByB.future.timeout(
      const Duration(seconds: 30),
    );
    expect(received['id'], idA);
    expect(received['x'], 1.0);

    await clientA.removeChannel(channelA);
    await clientB.removeChannel(channelB);
  });

  test('typed scores table: upsert and select through the draft API', () async {
    final id = clientA.auth.currentUser!.id;

    final before = await clientA
        .table(Scores.table)
        .select()
        .where(Scores.id.eq(id))
        .maybeSingle();

    await clientA
        .table(Scores.table)
        .upsert(
          ScoresInsert(
            id: id,
            name: 'SmokeTestPilot',
            wins: (before?.wins ?? 0) + 1,
            updatedAt: DateTime.now(),
          ),
        );

    final after = await clientA
        .table(Scores.table)
        .select()
        .where(Scores.id.eq(id))
        .single();
    expect(after.name, 'SmokeTestPilot');
    expect(after.wins, (before?.wins ?? 0) + 1);
  });
}
