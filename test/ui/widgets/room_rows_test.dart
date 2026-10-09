import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/l10n/l10n.dart';
import 'package:wargame/src/net/room.dart';
import 'package:wargame/src/ui/theme.dart';
import 'package:wargame/src/ui/widgets/room_invite.dart';
import 'package:wargame/src/ui/widgets/room_list.dart';

import '../../helpers/fakes.dart';

void main() {
  // The real font: the test font is far wider and would wrap the rows.
  setUpAll(() async {
    final loader = FontLoader('Roboto');
    for (final file in ['Regular', 'Medium', 'Bold', 'Black']) {
      loader.addFont(
        File('assets/fonts/Roboto-$file.ttf')
            .readAsBytes()
            .then((bytes) => ByteData.view(bytes.buffer)),
      );
    }
    await loader.load();
  });

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await openLocalStore();
    L10n.lang.value = AppLang.de;
  });

  // A small phone in portrait, inside the lobby padding.
  Future<void> show(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildBundeswehrTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('copy and share sit side by side in the invite', (tester) async {
    await show(tester, RoomInvite(game: offlineGame()));
    final copy = tester.getRect(find.text('KOPIEREN'));
    final share = tester.getRect(find.byIcon(Icons.ios_share));
    expect(share.center.dy, closeTo(copy.center.dy, 1));
    expect(find.text('TEILEN'), findsNothing);
    // Privat and public split the full width below, all at one height.
    await tester.pumpWidget(const SizedBox());
    final game = offlineGame()..mode.value = GameMode.multi;
    await show(tester, RoomInvite(game: game));
    final copyButton = tester.getRect(find.byType(TextButton));
    final private = tester.getRect(
      find
          .ancestor(of: find.text('PRIVAT'), matching: find.byType(Container))
          .first,
    );
    final public = tester.getRect(
      find
          .ancestor(
            of: find.text('ÖFFENTLICH'),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(private.width, closeTo(public.width, 1));
    expect(private.top, greaterThan(copyButton.bottom));
    expect(copyButton.height, 48);
    expect(private.height, 48);
    expect(tester.getSize(find.byType(IconButton)).height, 48);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the room code, join and scan share one row', (tester) async {
    await show(tester, RoomList(game: offlineGame()));
    final field = tester.getRect(find.byType(TextField));
    final join = tester.getRect(find.text('BEITRETEN'));
    expect(join.center.dy, closeTo(field.center.dy, 12));
    expect(find.text('QR-CODE SCANNEN'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
