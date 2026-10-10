// Writes the Impressum, the privacy notice and the licence terms as plain
// pages next to the web build, so they open at <game>/impressum/,
// <game>/datenschutz/ and <game>/lizenzen/ without starting the game. The App
// Store links the privacy page, the store texts the licence page.
//
//   dart run tool/legal_pages.dart build/web
//
// The text comes from lib/src/legal/legal_text.dart, the same the in-game
// dialog shows.

import 'dart:convert';
import 'dart:io';

import 'package:wargame/src/legal/legal_text.dart';

void main(List<String> args) {
  final out = Directory(args.isEmpty ? 'build/web' : args.first);
  _write(out, 'datenschutz', 'Datenschutz', privacy);
  _write(out, 'impressum', 'Impressum', imprint);
  // The component licences: the NOTICES file of the web build holds those of
  // every package and the engine, Roboto comes in full below it.
  final roboto = const HtmlEscape().convert(
    File('assets/fonts/Roboto_LICENSE.txt').readAsStringSync(),
  );
  _write(
    out,
    'lizenzen',
    'Lizenzen',
    licenses,
    extra:
        '<h2>Lizenztexte der Komponenten</h2>\n'
        '<p><a href="../play/assets/NOTICES">Lizenztexte aller Pakete und '
        'der Flutter-Engine</a></p>\n'
        '<h2>Roboto</h2>\n'
        '<p>Copyright 2011 Google Inc. Für das Spiel auf lateinische Zeichen '
        'gekürzt.</p>\n'
        '<pre>$roboto</pre>\n',
  );
}

void _write(
  Directory out,
  String slug,
  String title,
  List<LegalBlock> text, {
  String extra = '',
}) {
  final escape = const HtmlEscape();
  String paragraphs(String body) => body
      .trim()
      .split('\n\n')
      .map((p) => '<p>${escape.convert(p).replaceAll('\n', '<br>')}</p>')
      .join('\n');
  final body = StringBuffer();
  for (final block in text) {
    if (block.heading != null) {
      body.writeln('<h2>${escape.convert(block.heading!)}</h2>');
    }
    body.writeln(paragraphs(block.body));
  }
  body.write(extra);
  final page =
      '''
<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title · Panzergefecht</title>
<link rel="icon" type="image/png" href="../favicon.png">
<style>
  :root { color-scheme: dark; }
  body {
    margin: 0;
    background: #161c0f;
    color: #e6e2d3;
    font: 16px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
      Helvetica, Arial, sans-serif;
  }
  main {
    max-width: 720px;
    margin: 0 auto;
    padding: 32px 16px 64px;
  }
  h1 {
    color: #c2a878;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    margin: 0 0 8px;
  }
  h2 {
    color: #c2a878;
    font-size: 1rem;
    letter-spacing: 0.04em;
    margin: 28px 0 6px;
  }
  p { margin: 0 0 12px; }
  a { color: #ffb300; }
  .back { font-size: 0.9rem; }
  pre { font-size: 0.8rem; white-space: pre-wrap; color: #b9b5a6; }
</style>
</head>
<body>
<main>
<p class="back"><a href="../">Zum Spiel</a></p>
<h1>$title</h1>
$body</main>
</body>
</html>
''';
  final file = File('${out.path}/$slug/index.html')
    ..createSync(recursive: true)
    ..writeAsStringSync(page);
  stdout.writeln('Wrote ${file.path}');
}
