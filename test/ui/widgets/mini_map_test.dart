import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/ui/widgets/mini_map.dart';

import '../../helpers/fakes.dart';

void main() {
  // The map painted once and then stood still: the ticker
  // sat in a lazy field that only dispose touched, and since the map has
  // its own layer the HUD no longer repainted it either. Tanks and guns
  // that came after the first frame never showed.
  testWidgets('the map paints anew while the round runs', (tester) async {
    final game = (await tester.runAsync(loadedGame))!;
    game
      ..update(0)
      ..chooseMode(GameMode.defense)
      ..startRound();

    await tester.pumpWidget(Center(child: MiniMap(game: game)));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.descendant(
        of: find.byType(MiniMap),
        matching: find.byType(RepaintBoundary),
      ),
    );
    Layer? picture() => boundary.debugLayer?.firstChild;
    final first = picture();
    expect(first, isNotNull);

    await tester.pump(MiniMap.repaintEvery * 2);
    expect(picture(), isNot(same(first)));
  });
}
