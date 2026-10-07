class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wowtrfleffnfaiadhujj.supabase.co',
  );

  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable__f2Lb3vqafUovQCsYilkiQ_nVNkoNhS',
  );

  static const room = String.fromEnvironment('ROOM', defaultValue: 'main');

  /// Securing the guest account and signing in on another device. Off until
  /// the project sends mails through its own SMTP server, see the README.
  /// Build with `--dart-define=ACCOUNTS=true` to switch it on.
  static const accounts = bool.fromEnvironment('ACCOUNTS');
}
