import 'package:flutter/foundation.dart';

class Env {
  static const defaultSupabaseUrl = 'https://wowtrfleffnfaiadhujj.supabase.co';
  static const defaultSupabaseKey =
      'sb_publishable__f2Lb3vqafUovQCsYilkiQ_nVNkoNhS';

  /// The project the game talks to. A define that is no address falls back
  /// to the live project: build 4 shipped with all three defines glued into
  /// this one value by a misquoted command, and could not reach any server.
  static final supabaseUrl = checkedUrl(
    const String.fromEnvironment('SUPABASE_URL'),
    fallback: defaultSupabaseUrl,
  );

  static final supabaseKey = checkedKey(
    const String.fromEnvironment('SUPABASE_KEY'),
    fallback: defaultSupabaseKey,
  );

  /// [value] if it is a bare http(s) address, else [fallback]. Empty means
  /// not defined and falls back without a word.
  static String checkedUrl(String value, {required String fallback}) {
    if (value.isEmpty) {
      return fallback;
    }
    final uri = Uri.tryParse(value);
    final valid =
        !value.contains(RegExp(r'\s')) &&
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty &&
        !uri.hasQuery;
    if (valid) {
      return value;
    }
    debugPrint('SUPABASE_URL "$value" is no address, using $fallback');
    return fallback;
  }

  /// [value] unless it holds whitespace or a stray `--dart-define`.
  static String checkedKey(String value, {required String fallback}) {
    if (value.isEmpty) {
      return fallback;
    }
    if (value.contains(RegExp(r'\s')) || value.contains('--')) {
      debugPrint('SUPABASE_KEY is malformed, using the default key');
      return fallback;
    }
    return value;
  }

  /// Fixed room for local testing, so two instances meet. Without it every
  /// start opens a fresh private room, as in the browser.
  static const room = String.fromEnvironment('ROOM');

  /// The browser game. Room links from the apps point here, so the code
  /// scanned or opened anywhere leads into the same room.
  static const webUrl = String.fromEnvironment(
    'WEB_URL',
    defaultValue: 'https://www.regetskcob.de/wargame/',
  );

  /// Securing the guest account and signing in on another device. Off until
  /// the project sends mails through its own SMTP server, see the README.
  /// Build with `--dart-define=ACCOUNTS=true` to switch it on.
  static const accounts = bool.fromEnvironment('ACCOUNTS');

  /// Pilots a room holds, and the Realtime messages a second all rooms and
  /// phone controllers of the project may use together. Both follow the
  /// Supabase plan, whose limits count for the whole project. The project
  /// is on Pro: 500 a second, planned with 400, which carries rooms of four
  /// (README, "Rooms and room sizes"). Back on the free plan, build with
  /// `MAX_PILOTS=2` and `REALTIME_BUDGET=80`.
  static const maxPilots = int.fromEnvironment('MAX_PILOTS', defaultValue: 4);
  static const realtimeBudget = int.fromEnvironment(
    'REALTIME_BUDGET',
    defaultValue: 400,
  );
}
