import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/game_config.dart';

/// The few slots for rooms that play with more than one pilot (migration
/// 0015). Realtime's limit counts for the whole project, so the plan only
/// carries so many such rooms at once: [GameConfig.maxRooms].
class RoomSlots {
  RoomSlots(this._client);

  final SupabaseClient _client;

  /// Rooms holding a slot, as the last count found. Null until counted.
  static final live = ValueNotifier<int?>(null);

  /// Whether every slot is taken, as far as the last count knew.
  static bool get allTaken => (live.value ?? 0) >= GameConfig.maxRooms;

  /// Takes or refreshes the slot of [room]. False only when the server
  /// said every slot belongs to another room; when it cannot tell (offline,
  /// a database without the migration) nothing is held back.
  Future<bool> claim(String room) async {
    try {
      return await _client.rpc<bool>(
            'claim_room',
            params: {'p_room': room, 'p_max': GameConfig.maxRooms},
          ) !=
          false;
    } on Object {
      return true;
    }
  }

  /// Counts the rooms holding a slot into [live].
  Future<void> count() async {
    try {
      live.value = await _client.rpc<int>('live_room_count');
    } on Object {
      return;
    }
  }
}
