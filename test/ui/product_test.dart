import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horizont/horizont.dart';
import 'package:horizont/testing.dart';
import 'package:wargame/src/ui/product.dart';

Color _hex(Object? v) =>
    Color(int.parse('FF${(v! as String).substring(1)}', radix: 16));

void main() {
  final json = jsonDecode(
    File('tool/horizont/horizont.product.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('the product holds the guard rails of Horizont', () {
    expectProductHoldsContrast(panzergefecht);
  });

  test('product.dart and horizont.product.json say the same', () {
    expect(panzergefecht.displayName, json['name']);
    expect(panzergefecht.accentName, json['accentName']);
    for (final (mode, accent) in [
      ('light', panzergefecht.light),
      ('dark', panzergefecht.dark),
    ]) {
      final m = json[mode] as Map<String, dynamic>;
      expect(accent.accent, _hex(m['accent']), reason: '$mode accent');
      expect(accent.onAccent, _hex(m['on-accent']), reason: '$mode on-accent');
      expect(
        accent.accentTint,
        _hex(m['accent-tint']),
        reason: '$mode accent-tint',
      );
      expect(
        accent.accentText,
        _hex(m['accent-text']),
        reason: '$mode accent-text',
      );
    }
    final n = json['neutralDark'] as Map<String, dynamic>;
    final own = panzergefecht.neutralDark!;
    expect(
      [
        own.bg,
        own.surface,
        own.sunken,
        own.line,
        own.lineStrong,
        own.text,
        own.textMuted,
        own.textFaint,
      ],
      [
        for (final k in [
          'bg',
          'surface',
          'sunken',
          'line',
          'line-strong',
          'text',
          'text-muted',
          'text-faint',
        ])
          _hex(n[k]),
      ],
    );
    expect(panzergefecht.softLight, isNull);
    expect(json.containsKey('soft'), isFalse);
  });

  testWidgets('the mark draws the glyph', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: HorizontMark(
            panzergefecht,
            size: 48,
            color: const Color(0xFF000000),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(panzergefecht.mark, isNotNull);
    expect(find.bySemanticsLabel('Panzergefecht'), findsOneWidget);
  });
}
