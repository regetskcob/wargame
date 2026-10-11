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
import 'package:wargame/src/ui/widgets/vitals_plate.dart';
import 'package:wargame/src/ui/widgets/touch_controls.dart';

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
    await tester.tap(find.text('GESCHÜTZE'));
    await tester.pump();
    await tester.tap(find.text('KANONE 100'));
    // Too dear: nothing goes out.
    await tester.tap(find.text('HAUBITZE 220'), warnIfMissed: false);
    await tester.tap(find.text('AUFRÜSTUNG'));
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

  testWidgets('a tablet that opens a pairing link does not become a '
      'controller and says why', (tester) async {
    tester.view
      ..physicalSize = const Size(1180, 820)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGameTheme(),
        home: ControllerView(
          code: 'ABCDEFGH',
          name: 'iPad',
          onClose: () => closed = true,
        ),
      ),
    );
    expect(find.text('NUR AUF DEM HANDY'), findsOneWidget);
    expect(find.byType(TouchControls), findsNothing);

    await tester.tap(find.text('ZUM SPIEL'));
    expect(closed, isTrue);
  });

  // Issue 23 M6: the phone showed a bare circle for the shells where the
  // HUD shows a crate, and the HUD wrote "100%" where everything else
  // writes "100 %".
  testWidgets('the phone\'s gauges use the icons and the percent of the '
      'HUD plate', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final remote = PadRemote(
      'ABCDEFGH',
      client: SupabaseClient(
        'http://127.0.0.1:9',
        'test',
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
          autoRefreshToken: false,
        ),
      ),
    );
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
        hp: 0.8,
        ammo: 12,
        magazine: 20,
        fuel: 0.5,
      );
    await tester.pump();
    final padIcons = {
      for (final icon in tester.widgetList<Icon>(find.byType(Icon))) icon.icon,
    };
    final padTexts = [
      for (final text in tester.widgetList<Text>(find.byType(Text))) ?text.data,
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildGameTheme(),
        home: const Scaffold(
          body: Center(
            child: VitalsPlate(
              hp: 80,
              maxHp: 100,
              ammo: 12,
              maxAmmo: 20,
              endless: false,
              fuel: 0.5,
            ),
          ),
        ),
      ),
    );
    final plateIcons = {
      for (final icon in tester.widgetList<Icon>(find.byType(Icon))) icon.icon,
    };
    final plateTexts = [
      for (final text in tester.widgetList<Text>(find.byType(Text))) ?text.data,
    ];

    expect(plateIcons, hasLength(3));
    expect(padIcons, containsAll(plateIcons));
    final percent = RegExp(r'\d%|\d\s*%');
    for (final label in [...padTexts, ...plateTexts].where(percent.hasMatch)) {
      expect(label, matches(RegExp(r'\d %')), reason: label);
      expect(label, isNot(matches(RegExp(r'\d%'))), reason: label);
    }
    expect(plateTexts, contains('50 %'));
    expect(padTexts, contains('50 %'));

    await tester.pumpWidget(const SizedBox());
  });
}
