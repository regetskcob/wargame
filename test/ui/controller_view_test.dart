import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wargame/src/game/defense/tower.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/upgrades.dart';
import 'package:wargame/src/net/pad_link.dart';
import 'package:wargame/src/net/payloads/pad_payload.dart';
import 'package:wargame/src/ui/controller_view.dart';
import 'package:wargame/src/ui/theme.dart';

void main() {
  // The play test paired a phone and still had to build at the screen: the
  // shop is on the phone now.
  testWidgets('the phone builds, upgrades and decides in a defense round', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(844, 390)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final remote = PadRemote(
      'ABCDEFGH',
      // Never connected: the test plays the screen itself.
      client: SupabaseClient(
        'http://127.0.0.1:9',
        'test',
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
          autoRefreshToken: false,
        ),
      ),
    );
    final sent = <Map<String, dynamic>>[];
    remote.onSend = (event, payload, lane) {
      if (event == 'act') {
        sent.add(payload);
      }
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGameTheme(),
        home: ControllerView(code: 'ABCDEFGH', name: 'Phone', remote: remote),
      ),
    );
    remote
      ..debugScreen(lanes: false)
      ..status.value = const PadStatus(
        phase: GamePhase.playing,
        defense: true,
        credits: 120,
        shop: [(TowerKind.cannon, 100, true), (TowerKind.howitzer, 220, false)],
        upgrades: [(UpgradeKind.armor, 0, 3, 100)],
        deciding: true,
        canExtend: true,
        canEnd: true,
      );
    await tester.pump();

    expect(find.text('SIEG GESICHERT'), findsOneWidget);
    await tester.tap(find.text('TÜRME'));
    await tester.pump();
    await tester.tap(find.text('KANONE 100'));
    // Too dear: nothing goes out.
    await tester.tap(find.text('HAUBITZE 220'), warnIfMissed: false);
    await tester.tap(find.text('UPGRADES'));
    await tester.pump();
    await tester.tap(find.textContaining('PANZERUNG'));
    await tester.tap(find.text('4 WELLEN'));
    expect(tester.takeException(), isNull);
    expect(
      [for (final action in sent) (action['k'], action['i'])],
      [
        ('place', TowerKind.cannon.index),
        ('upgrade', UpgradeKind.armor.index),
        ('extend', 0),
      ],
    );

    await tester.pumpWidget(const SizedBox());
  });
}
