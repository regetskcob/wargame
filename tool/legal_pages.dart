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
  // every package and the engine, the fonts of Horizont come in full below
  // it (SIL Open Font License, Material Symbols under Apache 2.0).
  final escape = const HtmlEscape();
  final fonts = _horizontFonts();
  _write(
    out,
    'lizenzen',
    'Lizenzen',
    licenses,
    extra:
        '<h2>Lizenztexte der Komponenten</h2>\n'
        '<p><a href="../play/assets/NOTICES">Lizenztexte aller Pakete und '
        'der Flutter-Engine</a></p>\n'
        '<h2>Schriften</h2>\n'
        '<p>Horizont Sans und Horizont Mono (zugeschnitten aus Mona Sans '
        'und Monaspace) und Literata unter der SIL Open Font License 1.1, '
        'Material Symbols unter der Apache-Lizenz 2.0, gebündelt im '
        'Designsystem Horizont, das selbst unter der MIT-Lizenz steht.</p>\n'
        '<pre>${escape.convert(fonts.ofl)}</pre>\n'
        '<pre>${escape.convert(fonts.symbols)}</pre>\n',
  );
}

/// The licence texts that come with the fonts of the Horizont package,
/// found through the package config `flutter pub get` writes.
({String ofl, String symbols}) _horizontFonts() {
  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final horizont = (config['packages'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((p) => p['name'] == 'horizont');
  // rootUri is absolute or relative to the config file, without a slash.
  final root = Directory.current.uri
      .resolve('.dart_tool/')
      .resolve('${horizont['rootUri']}/');
  String read(String name) =>
      File.fromUri(root.resolve('fonts/$name')).readAsStringSync();
  return (ofl: read('OFL.txt'), symbols: read('MaterialSymbols-LICENSE.txt'));
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
<link rel="icon" type="image/png" sizes="32x32" href="../favicon-32.png">
<style>
  /* Horizont, Panzergefecht in the dark on its Gelände neutrals. The fonts
     are the ones the landing page serves from Horizont under /fonts/. */
  @font-face { font-family: "Mona Sans"; font-weight: 400; src: url("../fonts/MonaSans/MonaSans-Regular.woff2") format("woff2"); }
  @font-face { font-family: "Mona Sans"; font-weight: 600; src: url("../fonts/MonaSans/MonaSans-SemiBold.woff2") format("woff2"); }
  @font-face { font-family: "Mona Sans Display Expanded"; font-weight: 900; src: url("../fonts/MonaSans/MonaSansDisplayExpanded-Black.woff2") format("woff2"); }
  @font-face { font-family: "Monaspace Argon"; font-weight: 400; src: url("../fonts/Monaspace/MonaspaceArgon-Regular.woff2") format("woff2"); }
  :root {
    color-scheme: dark;
    --bg: #141a0e;
    --line: #2f3a24;
    --text: #e6e2d3;
    --text-muted: #b4ba9e;
    --accent-text: #ffc233;
  }
  body {
    margin: 0;
    background: var(--bg);
    color: var(--text);
    font: 16px/1.5 "Mona Sans", system-ui, sans-serif;
  }
  main {
    max-width: 720px;
    margin: 0 auto;
    padding: 32px 16px 64px;
  }
  h1 {
    font: 900 28px/34px "Mona Sans Display Expanded", "Mona Sans", sans-serif;
    letter-spacing: 0.02em;
    text-transform: uppercase;
    margin: 0 0 24px;
    padding-bottom: 12px;
    border-bottom: 2px solid var(--accent-text);
  }
  h2 {
    font: 600 11px/16px "Monaspace Argon", ui-monospace, monospace;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--text-muted);
    margin: 32px 0 8px;
    padding-top: 12px;
    border-top: 1px solid var(--line);
  }
  p { margin: 0 0 12px; }
  a { color: var(--accent-text); }
  .back { font-size: 14px; }
  pre {
    font: 12px/16px "Monaspace Argon", ui-monospace, monospace;
    white-space: pre-wrap;
    color: var(--text-muted);
  }
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
