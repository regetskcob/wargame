import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Runs the check Xcode does before every iOS build on the defines given.
Future<ProcessResult> _check(
  List<String> defines, {
  String configuration = 'Release',
}) {
  final encoded = defines.map((d) => base64.encode(utf8.encode(d))).join(',');
  return Process.run(
    'sh',
    ['tool/check_dart_defines.sh', encoded],
    environment: {'CONFIGURATION': configuration},
  );
}

void main() {
  test('passes clean defines', () async {
    final result = await _check([
      'SUPABASE_URL=https://abc.supabase.co',
      'SUPABASE_KEY=sb_publishable_x',
      'ACCOUNTS=true',
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
  });

  test('passes a build without defines', () async {
    expect((await _check([])).exitCode, 0);
  });

  test('stops the build 4 defines, glued into one value', () async {
    final result = await _check([
      'SUPABASE_URL=https://abc.supabase.co --dart-define=SUPABASE_KEY=sb_x '
          '--dart-define=ACCOUNTS=true',
    ]);
    expect(result.exitCode, 1);
    expect(result.stderr, contains('swallowed further defines'));
  });

  test('stops a release against a local server', () async {
    final local = ['SUPABASE_URL=http://127.0.0.1:54621'];
    expect((await _check(local)).exitCode, 1);
    expect((await _check(local, configuration: 'Debug')).exitCode, 0);
  });
}
