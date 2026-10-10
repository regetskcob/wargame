// Reads coverage/lcov.info from `flutter test --coverage` and fails below a
// floor of covered lines, so coverage can only go down on purpose.
//
//   dart run tool/coverage.dart --min 70
//
// Generated code is left out. Files under lib/ that no test loads at all
// are not in the report and so not in the share either; they are listed,
// since they are the biggest blind spots.

import 'dart:io';

void main(List<String> args) {
  final at = args.indexOf('--min');
  final floor = at >= 0 && at + 1 < args.length
      ? double.parse(args[at + 1])
      : 0.0;
  final report = File('coverage/lcov.info');
  if (!report.existsSync()) {
    stderr.writeln('No coverage/lcov.info: run flutter test --coverage first.');
    exit(2);
  }

  final files = <String, (int hit, int total)>{};
  String? current;
  var hit = 0;
  var total = 0;
  for (final line in report.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = _relative(line.substring(3));
      hit = total = 0;
    } else if (line.startsWith('DA:')) {
      total++;
      if (!line.endsWith(',0')) {
        hit++;
      }
    } else if (line == 'end_of_record' && current != null) {
      if (!current.endsWith('.g.dart')) {
        files[current] = (hit, total);
      }
      current = null;
    }
  }

  final covered = files.values.fold(0, (sum, f) => sum + f.$1);
  final lines = files.values.fold(0, (sum, f) => sum + f.$2);
  final share = lines == 0 ? 0.0 : 100 * covered / lines;

  final gaps = files.entries.toList()
    ..sort(
      (a, b) => (b.value.$2 - b.value.$1).compareTo(a.value.$2 - a.value.$1),
    );
  stdout.writeln('Most lines left uncovered:');
  for (final MapEntry(key: path, value: (h, t)) in gaps.take(10)) {
    stdout.writeln(
      '  ${(t - h).toString().padLeft(4)}  '
      '${(100 * h / t).toStringAsFixed(1).padLeft(5)} %  $path',
    );
  }

  final unloaded = [
    for (final entity in Directory('lib').listSync(recursive: true))
      if (entity is File &&
          entity.path.endsWith('.dart') &&
          !entity.path.endsWith('.g.dart') &&
          !files.containsKey(_relative(entity.path)))
        _relative(entity.path),
  ]..sort();
  if (unloaded.isNotEmpty) {
    stdout.writeln('Loaded by no test (or nothing to run in them):');
    for (final path in unloaded) {
      stdout.writeln('  $path');
    }
  }

  stdout.writeln(
    'Line coverage: ${share.toStringAsFixed(1)} % '
    '($covered of $lines lines in ${files.length} files), '
    'floor ${floor.toStringAsFixed(1)} %',
  );
  if (share < floor) {
    stderr.writeln('Coverage fell below the floor.');
    exit(1);
  }
}

String _relative(String path) {
  final normal = path.replaceAll(r'\', '/');
  final at = normal.lastIndexOf('lib/');
  return at < 0 ? normal : normal.substring(at);
}
