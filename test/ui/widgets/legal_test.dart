import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/ui/widgets/legal.dart';

void main() {
  Future<void> open(WidgetTester tester, String link) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LegalLinks())),
    );
    await tester.tap(find.text(link));
    await tester.pumpAndSettle();
  }

  testWidgets('the imprint names the operator and the address', (tester) async {
    await open(tester, 'Impressum');
    expect(find.textContaining('Kirchstraße 42'), findsWidgets);
    expect(find.textContaining('regetskcob@icloud.com'), findsWidgets);
    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kirchstraße 42'), findsNothing);
  });

  testWidgets('the privacy notice covers Supabase and the leaderboard', (
    tester,
  ) async {
    await open(tester, 'Datenschutz');
    expect(find.textContaining('Supabase'), findsWidgets);
    expect(find.textContaining('Bestenliste'), findsWidgets);
  });
}
