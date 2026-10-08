// Writes the Impressum and the privacy notice as plain pages next to the web
// build, so they open at <game>/impressum/ and <game>/datenschutz/ without
// starting the game. The App Store links the privacy page.
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
}

void _write(Directory out, String slug, String title, List<LegalBlock> text) {
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
