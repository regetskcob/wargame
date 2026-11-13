// The shape in which the Realtime client hands a broadcast to the game.
//
// NetService reads the fields of a game message (`id`, `x`, the room tag)
// straight from what onBroadcast emits. supabase_realtime 3.0.0-dev.10 and
// later wrap it in an envelope ({type, event, payload: {...}}); with that
// client every message of 1.8.3 (build 21) arrived without its fields, and
// old and new clients no longer heard each other. This pins the shape.
// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('a broadcast reaches the game with its fields on top', () async {
    final client = RealtimeClient('ws://localhost:1/realtime/v1');
    final channel = client.channel('game-arena-TEST');
    final first = channel.onBroadcast(event: 'state').first;
    // What a 1.8.2 client puts on the wire for `state`.
    channel.trigger('broadcast', {
      'type': 'broadcast',
      'event': 'state',
      'id': 'pilot-1',
      'x': 12.5,
    });
    final message = await first;
    expect(message['id'], 'pilot-1');
    expect(message['x'], 12.5);
    expect(message.containsKey('payload'), isFalse);
  });
}
