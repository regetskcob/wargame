import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:wargame/src/db/room_slots.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/l10n/l10n.dart';
import 'package:wargame/src/net/room.dart';
import 'package:wargame/src/net/room_directory.dart';
import 'package:wargame/src/ui/launch_view.dart';
import 'package:wargame/src/ui/widgets/room_list.dart';

import '../../helpers/fakes.dart';

void main() {
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await openLocalStore();
    L10n.lang.value = AppLang.de;
  });

  tearDown(() => RoomSlots.load.value = null);

  Future<void> show(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pump();
  }

  TankGame game() => offlineGame()..changeMode();

  testWidgets('the start page says when the budget has no room left', (
    tester,
  ) async {
    RoomSlots.load.value = GameConfig.realtimeBudget;
    await show(tester, LaunchView(game: game()));
    expect(
      find.textContaining('trägt der Server im Moment nicht'),
      findsOneWidget,
    );
    expect(find.text('ALLE RÄUME BELEGT'), findsOneWidget);
    // Single player stays as it was.
    expect(find.text('ALLEIN GEGEN CPU'), findsOneWidget);
  });

  testWidgets('with room in the budget the start page says nothing', (
    tester,
  ) async {
    RoomSlots.load.value = 0;
    await show(tester, LaunchView(game: game()));
    expect(
      find.textContaining('trägt der Server im Moment nicht'),
      findsNothing,
    );
    expect(find.text('GEFECHT MIT ANDEREN'), findsOneWidget);
  });

  testWidgets('a waiting room cannot be joined while the budget is full', (
    tester,
  ) async {
    final g = game();
    g.directory.rooms.value = const [
      RoomListing(room: 'ABCDE', host: 'Wolf', players: 1, inMatch: false),
    ];
    RoomSlots.load.value = GameConfig.realtimeBudget;
    await show(tester, RoomList(game: g));
    expect(find.text('BELEGT'), findsOneWidget);
    final button = tester.widget<TextButton>(
      find.ancestor(of: find.text('BELEGT'), matching: find.byType(TextButton)),
    );
    expect(button.onPressed, isNull);

    RoomSlots.load.value = 0;
    await tester.pump();
    expect(find.text('BEITRETEN'), findsWidgets);
    expect(find.text('BELEGT'), findsNothing);
  });

  testWidgets('a full room says so, whatever the slots', (tester) async {
    final g = game();
    g.directory.rooms.value = const [
      RoomListing(
        room: 'ABCDE',
        host: 'Wolf',
        players: GameConfig.maxPilots,
        inMatch: true,
      ),
    ];
    RoomSlots.load.value = 0;
    await show(tester, RoomList(game: g));
    expect(find.text('VOLL'), findsOneWidget);
  });
}
