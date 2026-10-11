// The room's order of keys (migration 0020) against a running local
// Supabase stack. Start it first with `supabase start` from the repository
// root. CI has no stack and leaves it out with `--exclude-tags supabase`.

@Tags(['supabase'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wargame/src/db/room_registry.dart';
import 'package:wargame/src/net/room_key.dart';

const _url = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'http://127.0.0.1:54621',
);
const _key = String.fromEnvironment(
  'SUPABASE_KEY',
  defaultValue: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
);

void main() {
  final clients = <SupabaseClient>[];

  /// A client of its own, signed in as a fresh guest unless [guest] is
  /// false.
  Future<SupabaseClient> client({bool guest = true}) async {
    final client = SupabaseClient(
      _url,
      _key,
      authOptions: AuthClientOptions(asyncStorage: MemoryAuthAsyncStorage()),
    );
    clients.add(client);
    if (guest) {
      await client.auth.signInAnonymously();
    }
    return client;
  }

  tearDownAll(() async {
    for (final client in clients) {
      await client.dispose();
    }
  });

  String room() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 8; i++)
        'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[random.nextInt(32)],
    ].join();
  }

  test('the server knows a key by the id the game speaks as', () async {
    final code = room();
    final owner = RoomKey.generate();
    final guest = RoomKey.generate();
    await RoomRegistry(await client()).enter(code, owner.encoded, owner: true);
    await RoomRegistry(await client()).enter(code, guest.encoded, owner: false);
    final order = await RoomRegistry(await client()).order(code);
    expect(order, isNotNull);
    expect(order!.pilots.keys, containsAll([owner.id, guest.id]));
    expect(order[owner.id]!.owner, isTrue);
    expect(order[guest.id]!.owner, isFalse);
    expect(
      order[owner.id]!.joinedAt.isAfter(order[guest.id]!.joinedAt),
      isFalse,
    );
  });

  test('a second account cannot take the room as its owner', () async {
    final code = room();
    final owner = RoomKey.generate();
    final poser = RoomKey.generate();
    await RoomRegistry(await client()).enter(code, owner.encoded, owner: true);
    await RoomRegistry(await client()).enter(code, poser.encoded, owner: true);
    final order = (await RoomRegistry(await client()).order(code))!;
    expect(order[owner.id]!.owner, isTrue);
    expect(order[poser.id]!.owner, isFalse);
  });

  test('the owner keeps the room with a new key after a reload', () async {
    final code = room();
    final device = await client();
    final first = RoomKey.generate();
    final second = RoomKey.generate();
    await RoomRegistry(device).enter(code, first.encoded, owner: true);
    await RoomRegistry(device).enter(code, second.encoded, owner: true);
    final order = (await RoomRegistry(device).order(code))!;
    expect(order[second.id]!.owner, isTrue);
  });

  test(
    'without a session a key is not entered, but the order is read',
    () async {
      final code = room();
      final key = RoomKey.generate();
      final anon = await client(guest: false);
      await RoomRegistry(
        anon,
        signIn: false,
      ).enter(code, key.encoded, owner: true);
      expect(anon.auth.currentSession, isNull);
      final order = await RoomRegistry(anon, signIn: false).order(code);
      expect(order, isNotNull);
      expect(order!.pilots, isEmpty);
      expect(order.hasOwner, isFalse);
    },
  );
}
