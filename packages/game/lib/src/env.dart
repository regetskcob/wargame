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
}
