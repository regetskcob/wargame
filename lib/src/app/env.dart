class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wowtrfleffnfaiadhujj.supabase.co',
  );

  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable__f2Lb3vqafUovQCsYilkiQ_nVNkoNhS',
  );

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
  /// the project sends mails through its own SMTP server, see docs/development.md.
  /// Build with `--dart-define=ACCOUNTS=true` to switch it on.
  static const accounts = bool.fromEnvironment('ACCOUNTS');

  /// Pilots a room holds, and the Realtime messages a second all rooms and
  /// phone controllers of the project may use together. Both follow the
  /// Supabase plan, whose limits count for the whole project. The project
  /// is on Pro: 500 a second, planned with 400, which carries rooms of four
  /// (docs/netcode.md, "Rooms and room sizes"). Back on the free plan, build
  /// with `MAX_PILOTS=2` and `REALTIME_BUDGET=80`.
  static const maxPilots = int.fromEnvironment('MAX_PILOTS', defaultValue: 4);
  static const realtimeBudget = int.fromEnvironment(
    'REALTIME_BUDGET',
    defaultValue: 400,
  );
}
