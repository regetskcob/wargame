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

  /// How long one check may take. The auth client retries a failing token
  /// refresh with backoff, and without a limit a heartbeat waiting on it
  /// kept the game "available" for minutes while nothing got through.
  static const timeout = Duration(seconds: 10);

  /// A guest sign-in on its way, shared by everybody who asks meanwhile:
  /// the start and the first heartbeat ask at the same moment, and two
  /// sign-ins would make two guests.
  static Future<bool>? _signingIn;

  /// Makes sure there is a session, the anonymous guest one if need be.
  /// False when the server refused or could not be reached.
  static Future<bool> ensureSession(AuthClient auth) async {
    if (auth.currentSession != null) {
      return true;
    }
    return _signingIn ??= _signIn(auth).whenComplete(() => _signingIn = null);
  }

  static Future<bool> _signIn(AuthClient auth) async {
    try {
      await auth.signInAnonymously().timeout(timeout);
      return true;
    } on Object catch (error) {
      debugPrint('No session from the server: $error');
      return false;
    }
  }

  /// Asks the server once: a session first, then [heartbeat]. A stored
  /// session alone proves nothing, the heartbeat has to get through. A
  /// database that does not know the heartbeat yet still answers.
  static Future<bool> check({
    required Future<bool> Function() session,
    required Future<void> Function() heartbeat,
  }) async {
    if (!await session()) {
      return false;
    }
    try {
      await heartbeat().timeout(timeout);
      return true;
    } on PostgrestApiException catch (error) {
      if (error.errorCode == 'PGRST202') {
        return true;
      }
      debugPrint('Server check failed: $error');
      return false;
    } on Object catch (error) {
      // Logged so a broken build shows its cause on the device, not only
      // the notice: build 4 failed here with a FormatException on its URL.
      debugPrint('Server check failed: $error');
      return false;
    }
  }
}
