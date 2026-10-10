import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  /// scanned or opened anywhere leads into the same room. The landing page
  /// one level up passes on links of older apps that still lack `play/`.
  static const webUrl = String.fromEnvironment(
    'WEB_URL',
    defaultValue: 'https://www.regetskcob.de/wargame/play/',
  );

  /// Securing the guest account and signing in on another device. Off until
  /// the project sends mails through its own SMTP server, see docs/development.md.
  /// Build with `--dart-define=ACCOUNTS=true` to switch it on.
  static const accounts = bool.fromEnvironment('ACCOUNTS');

  /// Pilots a room holds, and the Realtime messages a second all rooms and
  /// phone controllers of the project may use together. Both follow the
  /// Supabase plan, whose limits count for the whole project. The project
  /// is on Pro: 500 a second, planned with 400, which carries rooms of four
  /// (docs/netcode.md, "Rooms and room sizes"). Back on the free plan, build
  /// with `MAX_PILOTS=2` and `REALTIME_BUDGET=80`.
  /// Screenshot mode for the store pictures (store/ios/README.md): the own
  /// tank takes no damage, it stays day without fog, the difficulty starts
  /// on easy (endless ammunition), and a defense round opens at
  /// [shotWave] with a grown base and funds for guns. Playing a scene by
  /// hand in the simulator lost the tank within seconds and the light to
  /// chance. Never set it for a build that goes out.
  static const shots = bool.fromEnvironment('SHOTS');
  static const shotWave = int.fromEnvironment('SHOT_WAVE', defaultValue: 3);

  /// Draws both touch sticks held over to one side while nobody touches
  /// them, for the picture of the controls. The battle and the phone
  /// controller scenes of tool/store_shots.sh pose them as well.
  static bool get shotSticks =>
      const bool.fromEnvironment('SHOT_STICKS') ||
      shotScene == 'battle' ||
      shotScene == 'pad';

  /// The scene tool/store_shots.sh asks a screenshot build for, passed as
  /// a launch argument (`-SHOT_SCENE battle`), which iOS, tvOS and macOS
  /// put into the user defaults, so one build takes every picture: the game
  /// walks there by itself and saves its own frame to [shotOut]. Taking
  /// them by hand cost 10 to 20 tries a picture. Dart sees no environment
  /// variables on iOS, hence the arguments. Set by [loadShots].
  static String? shotScene;

  /// `de` or `en` for the scene, the language of the device otherwise.
  static String? shotLang;

  /// Where the finished frame goes, a path the app may write to.
  static String? shotOut;

  /// Reads the launch arguments of a screenshot build, see [shotScene].
  static Future<void> loadShots() async {
    if (!shots || kIsWeb) {
      return;
    }
    final prefs = SharedPreferencesAsync();
    shotScene = await prefs.getString('SHOT_SCENE');
    shotLang = await prefs.getString('SHOT_LANG');
    shotOut = await prefs.getString('SHOT_OUT');
  }

  static const maxPilots = int.fromEnvironment('MAX_PILOTS', defaultValue: 4);
  static const realtimeBudget = int.fromEnvironment(
    'REALTIME_BUDGET',
    defaultValue: 400,
  );
}
