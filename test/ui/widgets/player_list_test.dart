import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horizont/horizont.dart';
import 'package:wargame/src/ui/theme.dart';
import 'package:wargame/src/net/payloads/lobby_presence.dart';
import 'package:wargame/src/ui/widgets/player_list.dart';

LobbyPresence _member(String id, String name, {bool host = false}) =>
    LobbyPresence(
      id: id,
      name: name,
      colorIndex: 0,
      phase: 'lobby',
      host: host,
      owner: host,
    );

Future<void> _pump(WidgetTester tester, {String? hostId}) => tester.pumpWidget(
  MaterialApp(
    theme: buildGameTheme(),
    home: Scaffold(
      body: PlayerList(
        members: [
          _member('owner', 'Owner'),
          // Claims to host and to own the room in its presence.
          _member('poser', 'Poser', host: true),
        ],
        myId: 'owner',
        hostId: hostId,
        colorOf: (_) => Colors.white,
      ),
    ),
  ),
);

bool _starred(WidgetTester tester, String name) {
  final row = find.ancestor(
    of: find.textContaining(name),
    matching: find.byType(Row),
  );
  return find
      .descendant(of: row.first, matching: find.byIcon(HorizontSymbols.star))
      .evaluate()
      .isNotEmpty;
}

void main() {
  testWidgets('the star follows the ranking, not what a presence claims', (
    tester,
  ) async {
    await _pump(tester, hostId: 'owner');
    expect(_starred(tester, 'Owner'), isTrue);
    expect(_starred(tester, 'Poser'), isFalse);
  });

  testWidgets('before the ranking is known the claims count', (tester) async {
    await _pump(tester);
    expect(_starred(tester, 'Owner'), isFalse);
    expect(_starred(tester, 'Poser'), isTrue);
  });
}
