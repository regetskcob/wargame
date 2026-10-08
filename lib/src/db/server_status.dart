import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Whether the game's server answers. It goes down when Supabase turns the
/// project away, as it does once the free plan's monthly quota is used up
/// (every request then fails with 402), or while the device is offline.
/// Solo rounds need no server and go on; playing with others and the room
/// list wait until it is back. The heartbeat asks again once a minute.
class ServerStatus {
  ServerStatus._();

  static final available = ValueNotifier<bool>(true);

  /// Makes sure there is a session, the anonymous guest one if need be.
  /// False when the server refused or could not be reached.
  static Future<bool> ensureSession(AuthClient auth) async {
    if (auth.currentSession != null) {
      return true;
    }
    try {
      await auth.signInAnonymously();
      return true;
    } on Object {
      return false;
    }
  }

  /// Asks the server once: a session first, then [heartbeat]. A database
  /// that does not know the heartbeat yet still answers.
  static Future<bool> check({
    required Future<bool> Function() session,
    required Future<void> Function() heartbeat,
  }) async {
    if (!await session()) {
      return false;
    }
    try {
      await heartbeat();
      return true;
    } on PostgrestApiException catch (error) {
      return error.errorCode == 'PGRST202';
    } on Object {
      return false;
    }
  }
}
