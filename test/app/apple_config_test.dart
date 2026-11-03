import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/app/env.dart';

/// apple/App.xcconfig repeats defaults of [Env] for the widget and the
/// iMessage app, which cannot read Dart defines. A fork that changes one
/// and forgets the other would get a widget asking the old project.
void main() {
  final settings = _read(File('apple/App.xcconfig'));

  test('the Apple targets ask the same project as the game', () {
    expect(settings['APP_SUPABASE_URL'], Env.defaultSupabaseUrl);
    expect(settings['APP_SUPABASE_KEY'], Env.defaultSupabaseKey);
  });

  test('the iMessage app links the same browser game and room size', () {
    // Tests run without defines, so these are the defaults.
    expect(settings['APP_WEB_URL'], Env.webUrl);
    expect(settings['APP_MAX_PILOTS'], '${Env.maxPilots}');
  });

  test('the link domain is the browser game\'s', () {
    expect(Uri.parse(Env.webUrl).host, settings['APP_LINK_DOMAIN']);
  });
}

/// `NAME = value` lines, with the `$()` that keeps `//` from starting a
/// comment taken out again.
Map<String, String> _read(File file) => {
  for (final line in file.readAsLinesSync())
    if (RegExp(r'^([A-Z_]+)\s*=\s*(.*)$').firstMatch(line) case final match?)
      match.group(1)!: match.group(2)!.replaceAll(r'$()', '').trim(),
};
