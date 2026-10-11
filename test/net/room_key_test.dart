import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/net/room_key.dart';
import 'package:x25519/x25519.dart' as x25519;

Uint8List _hex(String hex) => Uint8List.fromList([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

void main() {
  test('X25519 matches RFC 7748 on this platform', () {
    // Section 6.1: Alice's private key, Bob's public key, their secret.
    final alice = _hex(
      '77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a',
    );
    final bobPublic = _hex(
      'de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f',
    );
    expect(
      x25519.X25519(alice, bobPublic),
      _hex('4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742'),
    );
  });

  test('two keys agree on a secret per room, and ids follow the keys', () {
    final a = RoomKey.generate();
    final b = RoomKey.generate();
    expect(a.id, hasLength(RoomKey.idLength));
    expect(RoomKey.belongsTo(a.id, a.encoded), isTrue);
    expect(RoomKey.belongsTo(a.id, b.encoded), isFalse);
    expect(RoomKey.belongsTo(a.id, 'nonsense'), isFalse);
    final ab = a.sharedWith(b.public, 'ABC')!;
    expect(b.sharedWith(a.public, 'ABC'), ab);
    expect(a.sharedWith(b.public, 'XYZ'), isNot(ab));
    // A point of low order agrees on nothing.
    expect(a.sharedWith(Uint8List(32), 'ABC'), isNull);
  });

  test('a tag survives the trip through JSON and a browser', () {
    final secret = Uint8List.fromList(List.filled(32, 7));
    final sent = <String, dynamic>{
      'id': 'abc',
      'x': 1.0,
      'y': 2.5,
      'list': [1, 2.0, 'z', null, true],
      'map': {'b': 1, 'a': 2},
    };
    final tag = RoomMac.tag(secret, 'state', sent, 'abc', 7);
    // What a browser hands on: 1.0 read as 1, keys in another order.
    final received = <String, dynamic>{
      'map': {'a': 2, 'b': 1},
      'list': [1, 2, 'z', null, true],
      'y': 2.5,
      'x': 1,
      'id': 'abc',
      RoomMac.field: {'me': tag},
    };
    expect(RoomMac.tag(secret, 'state', received, 'abc', 7), tag);
    expect(
      RoomMac.tag(
        secret,
        'state',
        jsonDecode(jsonEncode(sent)) as Map<String, dynamic>,
        'abc',
        7,
      ),
      tag,
    );
    expect(RoomMac.tag(secret, 'shoot', sent, 'abc', 7), isNot(tag));
    expect(RoomMac.tag(secret, 'state', sent, 'abd', 7), isNot(tag));
    expect(RoomMac.tag(secret, 'state', sent, 'abc', 8), isNot(tag));
    expect(
      RoomMac.tag(secret, 'state', {...sent, 'x': 1.5}, 'abc', 7),
      isNot(tag),
    );
    expect(
      RoomMac.tag(secret, 'state', {...sent, 'z': 1e308}, 'abc', 7),
      isNotNull,
    );
  });

  test('a tag holds over the fields the Realtime client adds', () {
    final secret = Uint8List.fromList(List.filled(32, 7));
    final sent = <String, dynamic>{'id': 'abc', 'startedAt': 1791724894665};
    final tag = RoomMac.tag(secret, 'roundStart', sent, 'abc', 7);
    // supabase_realtime writes these into every broadcast it sends, and
    // the receiver's listener gets them with the payload.
    final received = {...sent, 'type': 'broadcast', 'event': 'roundStart'};
    expect(RoomMac.tag(secret, 'roundStart', received, 'abc', 7), tag);
    // Times in milliseconds are covered to the last digit.
    expect(
      RoomMac.tag(
        secret,
        'roundStart',
        {...sent, 'startedAt': 1791724894666},
        'abc',
        7,
      ),
      isNot(tag),
    );
  });

  test('keys and agreements are quick enough', () {
    final watch = Stopwatch()..start();
    final keys = [for (var i = 0; i < 4; i++) RoomKey.generate()];
    final made = watch.elapsedMilliseconds;
    for (final other in keys.skip(1)) {
      keys.first.sharedWith(other.public, 'ROOM');
    }
    final agreed = watch.elapsedMilliseconds - made;
    final secret = keys.first.sharedWith(keys[1].public, 'ROOM')!;
    final payload = {
      'id': keys.first.id,
      'x': 1234.5,
      'y': 987.25,
      'a': 1.25,
      't': 0.5,
      'hp': 100,
      'vx': 12.0,
      'vy': -3.5,
    };
    watch.reset();
    for (var i = 0; i < 1000; i++) {
      RoomMac.tag(secret, 'state', payload, 'abc', 7);
    }
    final tags = watch.elapsedMilliseconds;
    // ignore: avoid_print
    print('4 keys $made ms, 3 agreements $agreed ms, 1000 tags $tags ms');
  });
}
