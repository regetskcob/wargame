import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/game_config.dart';
import 'server_status.dart';

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
    // A link opens the room before the guest sign-in is through; a claim
    // without a session was refused and then let in unchecked. It waits
    // for the sign-in the start shares (`ServerStatus.ensureSession`).
    if (!await ServerStatus.ensureSession(_client.auth)) {
      return true;
    }
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
    } on Object catch (error) {
      debugPrint('Claiming slot $key failed, letting it in: $error');
      return true;
    }
  }

  /// Waits in line for a slot of [messages] a second for the room [key]
  /// (migration 0023): null once the slot is taken, else the place in line.
  /// Null as well when the server cannot tell (offline, a database without
  /// the migration), as [claim] lets in then too.
  Future<QueueSpot?> queue(String key, int messages) async {
    try {
      final answer = await _client.rpc<Map<String, dynamic>>(
        'queue_claim',
        params: {
          'p_room': key,
          'p_load': messages,
          'p_budget': GameConfig.realtimeBudget,
        },
      );
      return QueueSpot.fromJson(answer);
    } on Object catch (error) {
      debugPrint('Waiting for slot $key failed, letting it in: $error');
      return null;
    }
  }

  /// Leaves the line, so those behind move up at once instead of after
  /// the 45 seconds a silent place is kept.
  Future<void> leaveQueue() async {
    try {
      await _client.rpc<void>('queue_leave');
    } on Object catch (error) {
      debugPrint('Leaving the queue failed: $error');
    }
  }

  /// Counts the loads of all slots into [load].
  Future<void> count() async {
    try {
      load.value = await _client.rpc<int>('live_load');
    } on Object catch (error) {
      debugPrint('Counting the slots failed: $error');
      return;
    }
  }
}

/// A place in the line for the Realtime budget.
@immutable
class QueueSpot {
  const QueueSpot(this.place, this.wait);

  /// Null when the answer says the slot is taken.
  static QueueSpot? fromJson(Map<String, dynamic> json) {
    if (json['granted'] == true) {
      return null;
    }
    return QueueSpot(
      (json['place'] as num?)?.toInt() ?? 0,
      Duration(seconds: (json['wait'] as num?)?.toInt() ?? 0),
    );
  }

  /// Not asked yet: the place is still unknown.
  static const unknown = QueueSpot(0, Duration.zero);

  /// 1 is next; 0 while unknown.
  final int place;

  /// A rough guess, shown as whole minutes.
  final Duration wait;

  @override
  bool operator ==(Object other) =>
      other is QueueSpot && other.place == place && other.wait == wait;

  @override
  int get hashCode => Object.hash(place, wait);
}
