import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/components/power_up.dart';
import 'package:wargame/src/watch/watch_overlays.dart';
import 'package:wargame/src/watch/watch_support.dart';
import 'package:wargame/src/watch/watch_widgets.dart';
import 'package:wargame/src/watch/wear_crown.dart';

import '../helpers/fakes.dart';

void main() {
  // A small round Wear OS watch: 384 pixels at twice the density.
  const watch = Size(192, 192);

  setUp(() {
    onWearForTesting = true;
    wearRoundForTesting = true;
  });

  tearDown(() {
    onWearForTesting = false;
    wearRoundForTesting = false;
  });

  Future<void> pumpOnWatch(WidgetTester tester, Widget child) async {
    tester.view
      ..physicalSize = watch * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Material(child: child)));
  }

  /// Whether all of [finder] lies inside the circle of the screen.
  bool insideCircle(WidgetTester tester, Finder finder) {
    final rect = tester.getRect(finder);
    final center = watch.center(Offset.zero);
    return [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
      // The corners of the largest square touch the circle: half a pixel of
      // rounding is allowed.
    ].every(
      (corner) => (corner - center).distance <= watch.shortestSide / 2 + 0.5,
    );
  }

  test('only a round Wear OS watch counts as round', () {
    expect(watchRound, isTrue);
    onWearForTesting = false;
    expect(watchRound, isFalse);
  });

  testWidgets('the inventory sits on a ring inside the circle, armour and '
      'magazine on the rim', (tester) async {
    final game = offlineGame();
    game.inventory
      ..add(PowerUpType.repair)
      ..add(PowerUpType.smoke)
      ..add(PowerUpType.shield);
    await pumpOnWatch(tester, WatchHud(game: game));

    expect(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is WatchRimPainter,
      ),
      findsOneWidget,
    );
    final slots = find.text('1');
    expect(slots, findsNWidgets(3));
    final centers = [for (var i = 0; i < 3; i++) tester.getCenter(slots.at(i))];
    for (var i = 0; i < 3; i++) {
      expect(insideCircle(tester, slots.at(i)), isTrue);
      // All below the middle, the first on the left.
      expect(centers[i].dy, greaterThan(watch.height / 2));
    }
    expect(centers[0].dx, lessThan(centers[1].dx));
    expect(centers[1].dx, lessThan(centers[2].dx));
    expect(centers[1].dx, closeTo(watch.width / 2, 0.5));
    // Each slot clear of its neighbour.
    expect((centers[1] - centers[0]).distance, greaterThan(32));
    // Stopped for the timer of the wave countdown.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the menus keep inside the largest square of the circle', (
    tester,
  ) async {
    await pumpOnWatch(
      tester,
      const WatchPage(
        children: [
          Text('PANZERGEFECHT', key: ValueKey('title')),
          WatchButton(label: 'SINGLE PLAYER', onPressed: null),
        ],
      ),
    );
    expect(insideCircle(tester, find.byKey(const ValueKey('title'))), isTrue);
    expect(insideCircle(tester, find.byType(OutlinedButton)), isTrue);
    final corner = watch.shortestSide * (1 - sqrt1_2) / 2;
    expect(tester.getTopLeft(find.byType(OutlinedButton)).dx, corner);
  });
}
