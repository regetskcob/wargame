import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/game_config.dart';

/// Shares the project's Realtime budget between rooms and phone controllers
/// (migrations 0015 and 0016). Realtime's limit counts for the whole
/// project, so every room with more than one pilot and every paired phone
/// takes a slot with the messages a second it costs, and a new one only
/// gets in while all of them together stay within
/// [GameConfig.realtimeBudget].
class RoomSlots {
  RoomSlots(this._client);

  final SupabaseClient _client;

  /// The loads of all slots together, as the last count found. Null until
  /// counted.
  static final load = ValueNotifier<int?>(null);

  /// Whether another room of two, CPU tanks included, would still fit, as
  /// far as the last count knew.
  static bool get allTaken =>
      (load.value ?? 0) + GameConfig.roomLoad(2, cpu: true) >
      GameConfig.realtimeBudget;

  /// Takes or refreshes the slot [key] with [messages] a second. False only
  /// when the server said the budget has no room for it; when it cannot
  /// tell (offline, a database without the migration) nothing is held
  /// back.
  Future<bool> claim(String key, int messages) async {
    try {
      return await _client.rpc<bool>(
            'claim_load',
            params: {
              'p_room': key,
              'p_load': messages,
              'p_budget': GameConfig.realtimeBudget,
            },
          ) !=
          false;
    } on Object {
      return true;
    }
  }

  /// Counts the loads of all slots into [load].
  Future<void> count() async {
    try {
      load.value = await _client.rpc<int>('live_load');
    } on Object {
      return;
    }
  }
}
