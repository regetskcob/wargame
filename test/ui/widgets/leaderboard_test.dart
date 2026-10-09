import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/db/supabase_schema.g.dart';
import 'package:wargame/src/l10n/l10n.dart';
import 'package:wargame/src/ui/widgets/leaderboard.dart';

import '../../helpers/fakes.dart';

void main() {
  setUp(() => L10n.lang.value = AppLang.de);

  testWidgets('a phone sees every column without scrolling sideways', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final scores = FakeScores(
      top: const [
        ScoresRow({
          'id': 'a',
          'name': 'Peter Maffay',
          'wins': 12,
          'kills': 345,
          'rating': 1234,
          'rated_rounds': 20,
        }),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Leaderboard(game: offlineGame(scores: scores)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final text in ['ABSCHÜSSE', 'WERTUNG', '1234', '345']) {
      final right = tester.getRect(find.text(text)).right;
      expect(right, lessThanOrEqualTo(390 - 16), reason: text);
    }
    expect(find.text('Peter Maffay'), findsOneWidget);
  });
}
