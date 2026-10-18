import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// One word per thing, wherever a player reads it: the game, the tutorial,
// the watch, iMessage, the Live Activity, the stores and the landing page.
// Issue 23 (W1–W7) found one defense shop under four names, "Stufe" for
// three things and the stores naming places the game does not have. The
// words decided there are kept here; docs/release-test-plan.md has the
// glossary in full.

/// A text a player can read, with where it stands.
typedef Text = ({String text, String where});

/// Words that must not come back, with the word to use instead.
const _german = <String, String>{
  r'\b(Türme|TÜRME|Turme)\b': 'GESCHÜTZE',
  r'\bBasis\b': 'Stützpunkt',
  r'\bLager\b|\bLAGER\b': 'Stützpunkt or Warteraum',
  r'\b(Revanche|REVANCHE|Nochmal|NOCHMAL)\b': 'NEUES SPIEL',
  // The currency of a defense round is Münzen. Mittel stays the medium
  // difficulty; as money it was "MITTEL 150", later "GELD".
  r'Zu wenig (Mittel|Geld)|ZU WENIG (MITTEL|GELD)|\b(MITTEL|GELD) \d|\bGeld\b|\bGELD\b':
      'Münzen',
  r'\b(Normal|NORMAL)\b': 'MITTEL',
  r'\bHost\b': 'Gastgeber',
  r'Wieder einsatzbereit|Neuer Panzer in': 'Einsatzbereit in',
  r'Raum-Code': 'Raumcode',
  r'Übungsplatz': 'Gefechtsplatz',
  r'Luftangriff': 'Luftschlag',
  r'DREI WEGE': 'VIER WEGE',
  r'\bHolt eure\b': 'Hol eure',
  // The word carries too much history in German (c99d069).
  r'\b(Sieg|SIEG|Siege|SIEGE)\b': 'Gewonnen',
};

const _english = <String, String>{
  r'\b(Towers?|TOWERS?)\b': 'guns',
  r'\b(next|nearest) turret\b|\bturrets\b': 'gun (turret is the tank\'s)',
  r'\b(money|Money|MONEY|funds|Funds|FUNDS)\b': 'coins',
  r'\b(rematch|Rematch|REMATCH)\b': 'NEW GAME',
  r'Training ground': 'Battlefield',
  r'\bRED VS BLUE\b': 'RED AGAINST BLUE',
  r'carry on on': 'keep playing on',
  // E-mail at the start of a sentence is the same word.
  r'\b(email|Email|EMAIL)\b': 'e-mail',
};

void main() {
  final texts = _texts();

  test('the sources hold the texts the test reads', () {
    // Guards the reader itself: a parser that finds nothing passes every
    // rule.
    expect(texts.de.length, greaterThan(500));
    expect(texts.en.length, greaterThan(500));
    expect(texts.de.map((t) => t.text), contains(contains('GESCHÜTZE')));
  });

  for (final (lang, rules, list) in [
    ('German', _german, texts.de),
    ('English', _english, texts.en),
  ]) {
    for (final MapEntry(key: pattern, value: instead) in rules.entries) {
      test('$lang texts say "$instead", not /$pattern/', () {
        final wrong = RegExp(pattern);
        final hits = [
          for (final t in list)
            if (wrong.hasMatch(t.text)) '${t.where}: ${t.text}',
        ];
        expect(hits, isEmpty, reason: hits.join('\n'));
      });
    }
  }
}

/// Every text of the game and around it, split by language.
({List<Text> de, List<Text> en}) _texts() {
  final de = <Text>[];
  final en = <Text>[];
  for (final root in const [
    'lib',
    'ios/MessagesExtension',
    'ios/OnlineWidget',
    'ios/Shared',
    'ios/Runner',
    'tvos/Runner',
  ]) {
    final dir = Directory(root);
    if (!dir.existsSync()) {
      continue;
    }
    for (final file in dir.listSync(recursive: true).whereType<File>()) {
      final path = file.path;
      if (!(path.endsWith('.dart') || path.endsWith('.swift')) ||
          path.endsWith('.g.dart')) {
        continue;
      }
      // The legal texts are laws and contracts, quoted as they stand.
      if (path.contains('/legal/')) {
        continue;
      }
      for (final (german, english, line) in trCalls(file.readAsStringSync())) {
        de.add((text: german, where: '$path:$line'));
        en.add((text: english, where: '$path:$line'));
      }
    }
  }
  // Store and landing page texts, whole files per language.
  for (final (dir, lang) in const [
    ('store/ios/metadata/de-DE', 'de'),
    ('store/ios/metadata/en-US', 'en'),
    ('store/android/metadata/android/de-DE', 'de'),
    ('store/android/metadata/android/en-US', 'en'),
  ]) {
    final folder = Directory(dir);
    if (!folder.existsSync()) {
      continue;
    }
    for (final file in folder.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.txt') || file.path.endsWith('_url.txt')) {
        continue;
      }
      _lines(file, lang == 'de' ? de : en);
    }
  }
  for (final (path, lang) in const [
    ('site/content/_index.de.md', 'de'),
    ('site/content/_index.en.md', 'en'),
    ('site/content/support.de.md', 'de'),
    ('site/content/support.en.md', 'en'),
    ('site/i18n/de.yaml', 'de'),
    ('site/i18n/en.yaml', 'en'),
  ]) {
    final file = File(path);
    if (file.existsSync()) {
      _lines(file, lang == 'de' ? de : en);
    }
  }
  return (de: de, en: en);
}

void _lines(File file, List<Text> into) {
  for (final (i, line) in file.readAsLinesSync().indexed) {
    if (line.trim().isNotEmpty) {
      into.add((text: line, where: '${file.path}:${i + 1}'));
    }
  }
}

/// The German and English text of every `tr(de, en)` call in [source]
/// with its line, both made of string literals (adjacent ones joined, an
/// interpolation read as "…"). Calls with other arguments are skipped.
List<(String, String, int)> trCalls(String source) {
  final calls = <(String, String, int)>[];
  for (final match in RegExp(r'(?<![\w.])tr\(').allMatches(source)) {
    var at = match.end;
    final german = _literals(source, at);
    if (german == null) {
      continue;
    }
    at = _skipSpace(source, german.$2);
    if (at >= source.length || source[at] != ',') {
      continue;
    }
    final english = _literals(source, at + 1);
    if (english == null) {
      continue;
    }
    final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
    calls.add((german.$1, english.$1, line));
  }
  return calls;
}

int _skipSpace(String s, int at) {
  var i = at;
  while (i < s.length) {
    if (s.startsWith('//', i)) {
      i = s.indexOf('\n', i);
      if (i < 0) {
        return s.length;
      }
    } else if (' \t\r\n+'.contains(s[i])) {
      // Swift joins literals with +.
      i++;
    } else {
      break;
    }
  }
  return i;
}

/// One or more adjacent string literals from [at], and where they end.
(String, int)? _literals(String s, int at) {
  final text = StringBuffer();
  var i = _skipSpace(s, at);
  var any = false;
  while (i < s.length) {
    var raw = false;
    if (s[i] == 'r' &&
        i + 1 < s.length &&
        (s[i + 1] == "'" || s[i + 1] == '"')) {
      raw = true;
      i++;
    }
    if (s[i] != "'" && s[i] != '"') {
      break;
    }
    final quote = s[i];
    i++;
    while (i < s.length && s[i] != quote) {
      final c = s[i];
      if (!raw && c == r'\') {
        // An escape, or Swift's \(…) interpolation.
        if (i + 1 < s.length && s[i + 1] == '(') {
          i = _closing(s, i + 1, '(', ')');
          text.write('…');
        } else {
          final next = i + 1 < s.length ? s[i + 1] : '';
          text.write(next == 'n' ? ' ' : next);
          i += 2;
        }
        continue;
      }
      if (!raw && c == r'$') {
        if (i + 1 < s.length && s[i + 1] == '{') {
          i = _closing(s, i + 1, '{', '}');
        } else {
          i++;
          while (i < s.length && RegExp(r'\w').hasMatch(s[i])) {
            i++;
          }
        }
        text.write('…');
        continue;
      }
      if (c == '\n') {
        // Not a literal after all.
        return null;
      }
      text.write(c);
      i++;
    }
    i++;
    any = true;
    i = _skipSpace(s, i);
  }
  return any ? (text.toString(), i) : null;
}

/// The index right after the bracket that closes the one at [at].
int _closing(String s, int at, String open, String close) {
  var depth = 0;
  for (var i = at; i < s.length; i++) {
    if (s[i] == open) {
      depth++;
    } else if (s[i] == close) {
      depth--;
      if (depth == 0) {
        return i + 1;
      }
    }
  }
  return s.length;
}
