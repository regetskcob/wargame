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
  /// the project sends mails through its own SMTP server, see the README.
  /// Build with `--dart-define=ACCOUNTS=true` to switch it on.
  static const accounts = bool.fromEnvironment('ACCOUNTS');

  /// Pilots a room holds, and how many rooms with more than one pilot play
  /// at once. Both follow the Supabase plan, whose Realtime limits count for
  /// the whole project: the free plan carries one room of two (README,
  /// "Rooms and room sizes", which also lists the values for Pro, such as
  /// `MAX_PILOTS=4`).
  static const maxPilots = int.fromEnvironment('MAX_PILOTS', defaultValue: 2);
  static const maxRooms = int.fromEnvironment('MAX_ROOMS', defaultValue: 1);
}
