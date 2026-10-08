import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The game calls database functions by name and with named parameters,
/// and the migrations define them. Nothing checks the two against each
/// other before a round on the live project does: a renamed parameter or a
/// function the client calls before its migration exists only shows up as
/// `PGRST202` or `permission denied` in the Supabase logs. This test reads
/// both sides and compares them.

/// A database function as the migrations leave it.
class _Function {
  _Function(this.params);

  final Set<String> params;

  /// Roles that may run it. Supabase grants new functions to `anon` and
  /// `authenticated`; the migrations revoke and grant from there.
  final roles = {'public', 'anon', 'authenticated'};
}

Map<String, _Function> _functionsFromMigrations() {
  final functions = <String, _Function>{};
  final files =
      Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final statement = RegExp(
    r'create\s+(?:or\s+replace\s+)?function\s+public\.(\w+)\s*\(([^)]*)\)'
    r'|drop\s+function\s+(?:if\s+exists\s+)?public\.(\w+)'
    r'|(grant|revoke)\s+execute\s+on\s+function\s+public\.(\w+)'
    r'(?:\s*\([^)]*\))?\s+(?:to|from)\s+([\w\s,]+?);',
    caseSensitive: false,
  );
  for (final file in files) {
    // Comments may mention functions as well.
    final sql = file
        .readAsStringSync()
        .split('\n')
        .map((line) => line.replaceFirst(RegExp('--.*'), ''))
        .join('\n');
    for (final match in statement.allMatches(sql)) {
      if (match.group(1) case final name?) {
        final params = {
          for (final param in match.group(2)!.split(','))
            if (param.trim().isNotEmpty) param.trim().split(RegExp(r'\s+'))[0],
        };
        final before = functions[name];
        functions[name] = _Function(params);
        if (before != null) {
          // `create or replace` keeps what was granted.
          functions[name]!.roles
            ..clear()
            ..addAll(before.roles);
        }
      } else if (match.group(3) case final name?) {
        functions.remove(name);
      } else {
        final function = functions[match.group(5)!];
        final roles = match
            .group(6)!
            .split(',')
            .map((r) => r.trim().toLowerCase());
        if (function == null) {
          continue;
        }
        if (match.group(4)!.toLowerCase() == 'grant') {
          function.roles.addAll(roles);
        } else {
          function.roles.removeAll(roles);
        }
      }
    }
  }
  return functions;
}

/// Every `rpc` call in the game: the function and the parameter names it
/// passes. Calls that pass a variable get the `p_` keys of map literals in
/// the same file.
List<(String file, String function, Set<String> params)> _callsInCode() {
  final calls = <(String, String, Set<String>)>[];
  final call = RegExp(
    r"\.rpc(?:<[^(]*?>)?\(\s*'(\w+)'(?:\s*,\s*params:\s*(\{[^}]*\}|\w+))?",
  );
  final key = RegExp(r"'(p_\w+)'\s*:");
  for (final file in Directory('lib').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) {
      continue;
    }
    final source = file.readAsStringSync();
    for (final match in call.allMatches(source)) {
      final params = match.group(2);
      final keys = params == null
          ? <String>{}
          : params.startsWith('{')
          ? {for (final k in key.allMatches(params)) k.group(1)!}
          : {for (final k in key.allMatches(source)) k.group(1)!};
      calls.add((file.path, match.group(1)!, keys));
    }
  }
  return calls;
}

void main() {
  final functions = _functionsFromMigrations();
  final calls = _callsInCode();

  test('the parser finds what it should', () {
    expect(functions['record_round']?.params, contains('p_name'));
    expect(functions['claim_load']?.params, contains('p_budget'));
    expect(calls.map((c) => c.$2), containsAll(['record_round', 'claim_load']));
  });

  test('every function the game calls exists in the migrations', () {
    for (final (file, name, _) in calls) {
      expect(
        functions,
        contains(name),
        reason:
            '$file calls $name, which no migration creates. Add the '
            'migration first and push it before the client (/db-migration).',
      );
    }
  });

  test('every parameter the game passes is one the function knows', () {
    for (final (file, name, params) in calls) {
      final known = functions[name]?.params ?? const {};
      for (final param in params) {
        // Keys of other functions in the same file are not this call's.
        final elsewhere = calls.any(
          (c) =>
              c.$1 == file &&
              c.$2 != name &&
              functions[c.$2]?.params.contains(param) == true,
        );
        if (elsewhere) {
          continue;
        }
        expect(
          known,
          contains(param),
          reason:
              '$file passes $param to $name, which takes ${known.toList()}. '
              'A renamed parameter makes PostgREST refuse the call.',
        );
      }
    }
  });

  test('a signed in player may run every function the game calls', () {
    for (final (file, name, _) in calls) {
      final roles = functions[name]?.roles ?? const {};
      expect(
        roles.contains('authenticated') || roles.contains('public'),
        isTrue,
        reason:
            '$file calls $name, but the migrations take it away from '
            'authenticated ($roles).',
      );
    }
  });
}
