// A game whose key did not make it into the room's order on the server
// ranks last on every other screen while it may host on its own: an owner
// whose entry failed lost the room to a guest. Failed entries are tried
// again.
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wargame/src/db/room_registry.dart';
import 'package:wargame/src/net/net_service.dart';
import 'package:wargame/src/net/room_key.dart';

class _FlakyRegistry extends RoomRegistry {
  _FlakyRegistry({required this.failures})
    : super(
        SupabaseClient(
          'http://127.0.0.1:9',
          'test',
          authOptions: const AuthClientOptions(
            authFlowType: AuthFlowType.implicit,
            autoRefreshToken: false,
          ),
        ),
        signIn: false,
      );

  int failures;
  var entries = 0;
  var orders = 0;

  @override
  Future<bool> enter(String room, String key, {required bool owner}) async {
    entries++;
    if (failures > 0) {
      failures--;
      return false;
    }
    return true;
  }

  @override
  Future<RoomOrder?> order(String room) async {
    orders++;
    return const RoomOrder({});
  }
}

NetService _net(RoomRegistry registry) {
  final key = RoomKey.generate();
  return NetService(myId: key.id, room: 'TEST1', key: key, registry: registry);
}

void main() {
  test('a failed entry into the room is tried again', () {
    fakeAsync((async) {
      final registry = _FlakyRegistry(failures: 2);
      final net = _net(registry)..enterForTest();
      async.flushMicrotasks();
      expect(registry.entries, 1);
      async.elapse(const Duration(seconds: 2));
      expect(registry.entries, 2);
      async.elapse(const Duration(seconds: 5));
      expect(registry.entries, 3);
      // In: the order is read, and no further entries follow.
      async.elapse(const Duration(seconds: 1));
      expect(registry.orders, greaterThan(0));
      async.elapse(const Duration(minutes: 2));
      expect(registry.entries, 3);
      net.dispose();
    });
  });

  test('a room without a server is not asked for ever', () {
    fakeAsync((async) {
      final registry = _FlakyRegistry(failures: 1000);
      final net = _net(registry)..enterForTest();
      async.elapse(const Duration(minutes: 5));
      expect(registry.entries, 5);
      net.dispose();
    });
  });

  test('leaving the room stops the tries', () {
    fakeAsync((async) {
      final registry = _FlakyRegistry(failures: 1000);
      final net = _net(registry)..enterForTest();
      async.flushMicrotasks();
      net.dispose();
      async.elapse(const Duration(minutes: 5));
      expect(registry.entries, 1);
    });
  });
}
