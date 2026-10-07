import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/src/game/kill_feed.dart';
import 'package:game/src/ui/widgets/kill_feed_view.dart';

KillEntry _entry({
  String? killer = 'Panzer-1',
  String victim = 'Panzer-2',
  DateTime? at,
}) => KillEntry(
  victim: victim,
  victimTeam: 2,
  killer: killer,
  killerTeam: 1,
  byMe: false,
  meDied: false,
  at: at ?? DateTime.now(),
);

void main() {
  testWidgets('shows who shot whom and drops old entries', (tester) async {
    final feed = ValueNotifier<List<KillEntry>>([
      _entry(),
      _entry(killer: null, victim: 'Panzer-3'),
      _entry(
        victim: 'Alt',
        at: DateTime.now().subtract(const Duration(seconds: 30)),
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: KillFeedView(feed: feed)),
      ),
    );

    expect(find.text('Panzer-1'), findsOneWidget);
    expect(find.text('Panzer-2'), findsOneWidget);
    expect(find.text('Panzer-3'), findsOneWidget);
    expect(find.text('ist ausgefallen'), findsOneWidget);
    expect(find.text('Alt'), findsNothing);

    feed.value = [...feed.value, _entry(victim: 'Panzer-4')];
    await tester.pump();
    expect(find.text('Panzer-4'), findsOneWidget);
  });
}
