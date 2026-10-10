import 'package:clock/clock.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/components/effects.dart';
import 'package:wargame/src/game/components/soldier.dart';
import 'package:wargame/src/game/components/tank_painter.dart';
import 'package:wargame/src/game/components/wreck.dart';
import 'package:wargame/src/net/payloads/soldier_payload.dart';

/// What a long defense round leaves behind must not pile up for the rest of
/// the round: fallen soldiers, stains, craters and smoking hulls.
void main() {
  Future<FlameGame> mount(WidgetTester tester, Component component) async {
    final game = FlameGame();
    game.world.add(component);
    await tester.pumpWidget(GameWidget(game: game, key: UniqueKey()));
    await tester.pump(const Duration(milliseconds: 16));
    return game;
  }

  SquadPayload squad(String id) => SquadPayload(
    id: 'host',
    owner: 'enemy',
    squad: id,
    x: 0,
    y: 0,
    at: clock.now().millisecondsSinceEpoch - 1000,
    rifles: 3,
  );

  testWidgets('fallen soldiers leave the field and do not come back', (
    tester,
  ) async {
    final field = SoldierField(
      seed: 1,
      startedAt: clock.now().millisecondsSinceEpoch,
      seeded: false,
    );
    await mount(tester, field);
    field.addSquad(squad('s1'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(field.all, hasLength(3));

    field.soldierByKey('s1/0')!
      ..dead = true
      ..removeFromParent();
    await tester.pump(const Duration(milliseconds: 16));
    expect(field.squads.keys, isNot(contains('s1/0')));
    expect(field.all, hasLength(2));
    // A late message about the fallen soldier finds nobody.
    expect(field.soldierByKey('s1/0'), isNull);

    // The same squad sent again does not raise the dead.
    field.addSquad(squad('s1'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(field.all, hasLength(2));
  });

  testWidgets('stains are capped even while old ones are on their way out', (
    tester,
  ) async {
    final field = SoldierField(
      seed: 1,
      startedAt: clock.now().millisecondsSinceEpoch,
      seeded: false,
    );
    await mount(tester, field);
    for (var i = 0; i < 200; i++) {
      field.addSplat(Vector2(i.toDouble(), 0), i);
      // Several in one frame, as a blast kills a whole squad at once.
      if (i % 10 == 9) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      field.children.whereType<BloodSplat>().length,
      lessThanOrEqualTo(60),
    );
  });

  test('only the newest craters stay', () {
    final tracks = TrackLayer();
    for (var i = 0; i < 1000; i++) {
      tracks.addCrater(Vector2.zero(), 20);
    }
    expect(tracks.craterCount, TrackLayer.craterCapacity);
  });

  testWidgets('a wreck stops smoking after a while', (tester) async {
    final wreck = Wreck(
      position: Vector2.zero(),
      angle: 0,
      tankType: TankType.values.first,
      hullSize: 40,
    );
    final game = await mount(tester, wreck);
    expect(wreck.smoking, isTrue);
    for (var t = 0.0; t < Wreck.smokeSeconds + 1; t += 0.5) {
      game.update(0.5);
    }
    expect(wreck.smoking, isFalse);
    // Let the last puffs fade, then nothing new may start.
    for (var i = 0; i < 10; i++) {
      game.update(0.5);
    }
    expect(
      game.world.children.whereType<ParticleEmitterComponent>().where(
        (puff) => !puff.isFinished,
      ),
      isEmpty,
    );
  });
}
