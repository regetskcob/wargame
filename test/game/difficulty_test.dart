import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/bot_level.dart';
import 'package:wargame/src/game/components/power_up.dart';
import 'package:wargame/src/game/round_state.dart';
import 'package:wargame/src/game/terrain.dart';
import 'package:wargame/src/net/payloads/strike_payload.dart';

void main() {
  final area = Rect.fromCircle(center: Offset.zero, radius: 900);

  group('terrain', () {
    test('flat on easy, hilly on normal, more so on hard', () {
      expect(Terrain.forSeed(5, BotLevel.easy, area: area).isFlat, isTrue);
      final normal = Terrain.forSeed(5, BotLevel.normal, area: area);
      final hard = Terrain.forSeed(5, BotLevel.hard, area: area);
      expect(normal.hills, isNotEmpty);
      expect(hard.hills.length, greaterThan(normal.hills.length));
      final steepest = hard.hills
          .map((h) => h.height.abs())
          .reduce((a, b) => a > b ? a : b);
      expect(steepest, greaterThan(1));
    });

    test('every client raises the same hills', () {
      final a = Terrain.forSeed(9, BotLevel.hard, area: area);
      final b = Terrain.forSeed(9, BotLevel.hard, area: area);
      expect(
        [for (final h in a.hills) (h.centre, h.radius, h.height)],
        [for (final h in b.hills) (h.centre, h.radius, h.height)],
      );
    });

    test('uphill is slower, downhill faster, flat ground is neutral', () {
      final terrain = Terrain([Hill(Vector2.zero(), 200, 1)]);
      final side = Vector2(-140, 0);
      final up = terrain.speedFactor(side, Vector2(1, 0));
      final down = terrain.speedFactor(side, Vector2(-1, 0));
      expect(up, lessThan(1));
      expect(down, greaterThan(1));
      expect(terrain.speedFactor(Vector2(5000, 0), Vector2(1, 0)), 1);
      expect(Terrain.flat.speedFactor(side, Vector2(1, 0)), 1);
      expect(terrain.heightAt(Vector2.zero()), closeTo(1, 1e-9));
    });
  });

  test('crates follow the level', () {
    final easy = {
      for (var i = 0; i < 400; i++)
        PowerUpType.fromRoll(i / 400, BotLevel.easy),
    };
    expect(easy, isNot(contains(PowerUpType.ammo)));
    expect(easy, isNot(contains(PowerUpType.fuel)));
    expect(easy, isNot(contains(PowerUpType.airstrike)));
    final normal = {
      for (var i = 0; i < 400; i++)
        PowerUpType.fromRoll(i / 400, BotLevel.normal),
    };
    expect(normal, containsAll([PowerUpType.ammo, PowerUpType.fuel]));
    expect(normal, isNot(contains(PowerUpType.airstrike)));
    final hard = {for (var i = 0; i < 400; i++) PowerUpType.fromRoll(i / 400)};
    expect(hard, containsAll(PowerUpType.values));
  });

  test('CPU tanks count for the rating', () {
    final round = RoundState(
      seed: 1,
      startedAt: 2,
      participants: const ['cpu-1', 'cpu-2', 'me'],
      bots: const {'cpu-1': 0, 'cpu-2': 0},
    );
    round.markDead('cpu-1');
    round.markDead('me');
    final cpu = round.cpuPlacementsOf('me');
    expect((cpu.beaten, cpu.beatenBy), (1, 1));
    expect(BotLevel.hard.rating, greaterThan(BotLevel.easy.rating));
  });

  test('the first bomb of an air strike tells where the bomber comes from', () {
    final bomb = ArtilleryPayload.fromJson(
      const ArtilleryPayload(
        id: 'a',
        strikeId: 'a-j1',
        x: 1,
        y: 2,
        at: 3,
        jetX: -500,
        jetY: 40,
      ).toJson(),
    );
    expect((bomb.jetX, bomb.jetY), (-500.0, 40.0));
    expect(
      ArtilleryPayload.fromJson(
        const ArtilleryPayload(
          id: 'a',
          strikeId: 's',
          x: 0,
          y: 0,
          at: 1,
        ).toJson(),
      ).jetX,
      isNull,
    );
  });
}
