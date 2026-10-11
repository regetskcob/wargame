import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'server_status.dart';

/// When a key came into a room and whether it is the owner's, by the
/// server (migration 0020).
typedef RoomPilot = ({DateTime joinedAt, bool owner});

/// The keys of a room as the server keeps them, see [RoomRegistry].
class RoomOrder {
  const RoomOrder(this.pilots);

  /// Every key the server knows in the room, by id.
  final Map<String, RoomPilot> pilots;

  /// Whether an account owns the room. Rooms opened by older builds have
  /// no owner.
  bool get hasOwner => pilots.values.any((pilot) => pilot.owner);

  RoomPilot? operator [](String id) => pilots[id];
}

/// Enters this game's key into the room and reads who came when, so every
/// client ranks the host the same way and nobody can take the role by
/// claiming to own the room or to have come first (migration 0020).
class RoomRegistry {
  RoomRegistry(this._client, {this.signIn = true});

  final SupabaseClient _client;

  /// Whether entering may sign in as a guest first. The connection of a
  /// second player on a screen stays without a session.
  final bool signIn;

  /// Enters the key [key] into [room], as its owner when [owner] and the
  /// room is not somebody else's. Without a session (the second player on
  /// a screen) nothing is entered: that key just ranks after the entered
  /// ones. False when it is worth trying again: no session could be had,
  /// or the server failed (a busy database cancelled the call after its
  /// statement timeout on a local stack).
  Future<bool> enter(String room, String key, {required bool owner}) async {
    final session = signIn
        ? await ServerStatus.ensureSession(_client.auth)
        : _client.auth.currentSession != null;
    if (!session) {
      return !signIn;
    }
    try {
      await _client.rpc<bool>(
        'enter_room',
        params: {'p_room': room, 'p_key': key, 'p_owner': owner},
      );
      return true;
    } on Object catch (error) {
      debugPrint('Entering room $room failed: $error');
      return false;
    }
  }

  /// The keys of [room], or null when the server cannot tell (offline, a
  /// database without the migration).
  Future<RoomOrder?> order(String room) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'room_order',
        params: {'p_room': room},
      );
      return RoomOrder({
        for (final row in rows.cast<Map<String, dynamic>>())
          if (row['id'] is String && row['joined_at'] is String)
            row['id'] as String: (
              joinedAt: DateTime.parse(row['joined_at'] as String),
              owner: row['owner'] == true,
            ),
      });
    } on Object catch (error) {
      debugPrint('Reading the order of room $room failed: $error');
      return null;
    }
  }
}
