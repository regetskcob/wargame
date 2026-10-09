import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/app/env.dart';

void main() {
  const fallback = 'https://fallback.supabase.co';

  group('checkedUrl', () {
    test('keeps a plain address', () {
      expect(
        Env.checkedUrl('https://abc.supabase.co', fallback: fallback),
        'https://abc.supabase.co',
      );
      expect(
        Env.checkedUrl('http://127.0.0.1:54621', fallback: fallback),
        'http://127.0.0.1:54621',
      );
    });

    test('falls back when nothing is defined', () {
      expect(Env.checkedUrl('', fallback: fallback), fallback);
    });

    test('falls back on defines glued into one value', () {
      // What build 4 shipped with.
      expect(
        Env.checkedUrl(
          'https://abc.supabase.co --dart-define=SUPABASE_KEY=sb_x '
          '--dart-define=ACCOUNTS=true',
          fallback: fallback,
        ),
        fallback,
      );
    });

    test('falls back on no address at all', () {
      expect(Env.checkedUrl('abc.supabase.co', fallback: fallback), fallback);
      expect(Env.checkedUrl('ftp://abc', fallback: fallback), fallback);
    });
  });

  group('checkedKey', () {
    test('keeps a key and drops a glued one', () {
      expect(
        Env.checkedKey('sb_publishable_x', fallback: 'd'),
        'sb_publishable_x',
      );
      expect(Env.checkedKey('', fallback: 'd'), 'd');
      expect(
        Env.checkedKey('sb_x --dart-define=ACCOUNTS=true', fallback: 'd'),
        'd',
      );
    });
  });

  test('the build in use carries usable values', () {
    expect(Uri.parse(Env.supabaseUrl).host, isNotEmpty);
    expect(Env.supabaseKey, isNot(contains(' ')));
  });
}
