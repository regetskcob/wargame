import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wargame/src/game/defense/tower.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/components/power_up.dart';
import 'package:wargame/src/game/special_weapon.dart';
import 'package:wargame/src/game/upgrades.dart';
import 'package:wargame/src/net/pad_link.dart';
import 'package:wargame/src/net/payloads/pad_payload.dart';
import 'package:wargame/src/ui/controller_view.dart';
import 'package:wargame/src/ui/theme.dart';
import 'package:wargame/src/ui/widgets/inventory_bar.dart';
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

  // Pen test: real phones were not at hand, so five fingers at once are
  // played here: both thumbs on the sticks, a finger on the special weapon,
  // one tapping an item, one resting, while the screen takes the aim assist
  // away and the controls are built anew under the thumbs. What goes out
  // after the last finger lifts must hold nothing down.
  testWidgets('five fingers on the phone, controls rebuilt under them, '
      'leave nothing held', (tester) async {
    tester.view
      ..physicalSize = const Size(844, 390)
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
    final pads = <Map<String, dynamic>>[];
    final acts = <Map<String, dynamic>>[];
    remote.onSend = (event, payload, lane) =>
        (event == 'pad'
                ? pads
                : event == 'act'
                ? acts
                : <Object>[])
            .add(payload);
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
        special: SpecialWeapon.drone,
        charges: 2,
        items: [(PowerUpType.repair, 1)],
      );
    await tester.pump();

    var now = DateTime(2026, 10, 11, 12);
    Map<String, dynamic> sendNow() {
      now = now.add(PadRemote.inputKeepalive);
      withClock(Clock.fixed(now), remote.tick);
      return pads.last;
    }

    var pointer = 20;
    Future<TestGesture> finger(Offset at) => tester.startGesture(
      at,
      pointer: pointer++,
      kind: PointerDeviceKind.touch,
    );
    final drive = await finger(const Offset(120, 330));
    await drive.moveBy(const Offset(40, -30));
    final aim = await finger(const Offset(730, 340));
    await aim.moveBy(const Offset(-60, 0));
    final weapon = await finger(tester.getCenter(find.text('DROHNE')));
    final rest = await finger(const Offset(420, 200));
    await tester.pump();
    var sent = sendNow();
    expect(sent['d'], isNotNull);
    expect(sent['h'] && sent['f'] && sent['s'], isTrue);

    // A fifth finger uses the item while the others hold.
    final item = await finger(tester.getCenter(find.byType(InventoryStrip)));
    await item.up();
    await tester.pump();
    expect(acts.map((a) => a['k']), contains('item'));

    // The screen switches the aim assist off: the controls are built anew
    // while all those fingers are down.
    remote.status.value = const PadStatus(
      phase: GamePhase.playing,
      special: SpecialWeapon.drone,
      charges: 2,
      items: [(PowerUpType.repair, 1)],
      assist: false,
    );
    await tester.pump();
    sent = sendNow();
    expect(sent['d'], isNull);
    expect(sent['h'] || sent['f'] || sent['s'], isFalse);

    // The fingers come up on the new controls in odd order, one cancelled.
    await aim.moveBy(const Offset(10, 10));
    await weapon.up();
    await drive.cancel();
    await rest.up();
    await aim.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
    sent = sendNow();
    expect(sent['d'], isNull);
    expect(sent['h'] || sent['f'] || sent['s'], isFalse);

    // And the new sticks answer the next touch.
    final again = await finger(const Offset(120, 330));
    await again.moveBy(const Offset(0, -50));
    await tester.pump();
    expect(sendNow()['d'], isNotNull);
    await again.up();
    await tester.pump();
    expect(sendNow()['d'], isNull);

    await tester.pumpWidget(const SizedBox());
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
