import 'package:wargame/src/game/bot_level.dart';
import 'package:clock/clock.dart';

import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/components/cover_field.dart';
import 'package:wargame/src/game/components/mud_field.dart';
import 'package:wargame/src/game/components/tank_painter.dart';
import 'package:wargame/src/game/defense/defense_map.dart';
import 'package:wargame/src/game/flag_match.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/island_shape.dart';
import 'package:wargame/src/game/map_theme.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/game/tank_stats.dart';
import 'package:wargame/src/game/weather.dart';
import 'package:wargame/src/net/payloads/lobby_presence.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final random = Random(7);
  final seeds = [for (var i = 0; i < 300; i++) random.nextInt(1 << 30)];

  group('seed marks', () {
    test('every map comes back out of the seed made for it, the sky stays', () {
      for (final seed in seeds) {
        for (var map = 0; map < MapTheme.all.length; map++) {
          final marked = MapTheme.seedFor(seed, map);
          expect(MapTheme.indexOf(marked), map, reason: '$seed $map');
          expect(
            Conditions.forSeed(marked).sky,
            Conditions.forSeed(seed).sky,
            reason: 'the opening sky is kept',
          );
        }
      }
    });

    test('a classic map stays where an older client reads it', () {
      for (final seed in seeds) {
        for (var map = 0; map < MapTheme.classic; map++) {
          expect(MapTheme.seedFor(seed, map) % 4, map);
        }
      }
    });

    test('layouts and maps are marked apart and keep each other', () {
      for (final seed in seeds) {
        for (var map = 0; map < MapTheme.all.length; map++) {
          for (var layout = 0; layout < DefenseMap.layoutCount; layout++) {
            final withLayout = DefenseMap.seedForLayout(
              MapTheme.seedFor(seed, map),
              layout,
            );
            expect(MapTheme.indexOf(withLayout), map);
            if (layout >= DefenseMap.classicLayouts) {
              expect(DefenseMap.layoutFor(withLayout), layout);
            } else {
              expect(
                DefenseMap.layoutFor(withLayout),
                lessThan(DefenseMap.classicLayouts),
              );
            }
          }
        }
      }
    });
  });

  group('islands', () {
    final shape = IslandShape.forSeed(12345);

    test('more water than land inside the field', () {
      var land = 0;
      var all = 0;
      for (var x = -900.0; x <= 900; x += 20) {
        for (var y = -900.0; y <= 900; y += 20) {
          final at = Vector2(x, y);
          if (at.length > GameConfig.worldRadius) {
            continue;
          }
          all++;
          if (shape.land(at)) {
            land++;
          }
        }
      }
      expect(land / all, lessThan(0.5));
      expect(land / all, greaterThan(0.2));
    });

    test('the middle and both flag bases are dry, every start lands', () {
      expect(shape.land(Vector2.zero()), isTrue);
      expect(shape.land(FlagMatch.baseOf(1)), isTrue);
      expect(shape.land(FlagMatch.baseOf(2)), isTrue);
      for (var i = 0; i < 36; i++) {
        final ring = Vector2(cos(i * pi / 18), sin(i * pi / 18))
          ..scale(GameConfig.spawnRadius);
        expect(shape.islandAt(shape.onLand(ring, margin: 40)), isNot(-1));
      }
    });

    test('shallows along the shore, deep water beyond, bridges across', () {
      final island = shape.islands[1];
      final out = (island.centre - shape.islands[0].centre).normalized();
      final angle = atan2(out.y, out.x);
      final shore = island.centre + out * island.shoreAt(angle);
      expect(shape.shallow(shore + out * 20), isTrue);
      expect(shape.deep(shore + out * 160), isTrue);
      for (final bridge in shape.bridges) {
        final middle = (bridge.start + bridge.end) / 2;
        expect(shape.land(middle), isTrue);
        final side = Vector2(-bridge.along.y, bridge.along.x);
        expect(shape.deep(middle + side * 120), isTrue, reason: 'off bridge');
      }
    });

    test('a tank finds its way to every island over the bridges', () {
      for (var a = 0; a < shape.islands.length; a++) {
        for (var b = 0; b < shape.islands.length; b++) {
          final from = shape.islands[a].centre;
          final to = shape.islands[b].centre;
          final next = shape.waypoint(from, to);
          if (a == b) {
            expect(next, to);
          } else {
            expect(next, isNot(to));
            expect(shape.islandAt(next), a, reason: 'entry on $a for $b');
          }
        }
      }
      final bridge = shape.bridges.first;
      final onIt = (bridge.start + bridge.end) / 2;
      final far = shape.islands[bridge.to].centre;
      expect(shape.islandAt(shape.waypoint(onIt, far)), bridge.to);
    });

    test('nothing stands in the water or on a bridge', () {
      final seed = MapTheme.seedFor(99, MapTheme.all.indexOf(MapTheme.isles));
      final cover = CoverField(seed: seed);
      cover.onLoad();
      final islands = IslandShape.forSeed(seed);
      for (final tree in cover.trees) {
        expect(islands.islandAt(tree.position), isNot(-1));
      }
      for (final obstacle in cover.obstacles) {
        expect(islands.islandAt(obstacle.position), isNot(-1));
      }
      final mud = MudField(seed: seed, theme: MapTheme.isles);
      expect(mud.slowdown, lessThan(0.6));
    });

    test('CPU tanks never drive into deep water and get about', () async {
      var now = clock.now();
      await withClock(Clock(() => now), () async {
        final game = await loadedGame();
        game
          ..chooseMode(GameMode.solo)
          ..mapChoice.value = MapTheme.all.indexOf(MapTheme.isles)
          ..botLevel.value = BotLevel.normal
          ..startRound(startedAt: now.millisecondsSinceEpoch);
        await Future<void>.delayed(Duration.zero);
        game.update(0);
        final islands = game.mudField!.islands!;
        final starts = {
          for (final e in game.botTanks.entries)
            e.key: e.value.position.clone(),
        };
        expect(starts, isNotEmpty);
        const step = Duration(microseconds: 33333);
        for (var frame = 0; frame < 30 * 30; frame++) {
          game.update(step.inMicroseconds / 1e6);
          await Future<void>.delayed(Duration.zero);
          now = now.add(step);
          for (final tank in game.botTanks.values) {
            expect(islands.deep(tank.position), isFalse, reason: '$frame');
          }
          if (game.phase.value != GamePhase.playing) {
            break;
          }
        }
        final moved = game.botTanks.entries.where(
          (e) => e.value.position.distanceTo(starts[e.key]!) > 100,
        );
        expect(moved, isNotEmpty);
      });
    });
  });

  group('content level', () {
    LobbyPresence older(String id) =>
        LobbyPresence(id: id, name: 'ALT', colorIndex: 0, phase: 'lobby');

    test(
      'a room with an older client gets only classic maps and layouts',
      () async {
        final game = await loadedGame(net: FakeNet(isHost: true));
        game.chooseMode(GameMode.multi);
        game.net.onRosterChanged?.call([older('old')]);
        expect(game.roomContent, 0);
        game.mapChoice.value = MapTheme.all.indexOf(MapTheme.isles);
        for (var i = 0; i < 40; i++) {
          game.startRound(startedAt: DateTime.now().millisecondsSinceEpoch);
          final seed = game.round!.seed;
          expect(MapTheme.indexOf(seed), lessThan(MapTheme.classic));
          expect(
            DefenseMap.layoutFor(seed),
            lessThan(DefenseMap.classicLayouts),
          );
          game.phase.value = GamePhase.lobby;
        }
      },
    );

    test('alone or among current clients the newer maps come up', () async {
      final game = await loadedGame(net: FakeNet(isHost: true));
      game.chooseMode(GameMode.solo);
      expect(game.roomContent, GameConfig.contentLevel);
      game.mapChoice.value = MapTheme.all.indexOf(MapTheme.mountainForest);
      game.startRound(startedAt: DateTime.now().millisecondsSinceEpoch);
      expect(MapTheme.forSeed(game.round!.seed), MapTheme.mountainForest);
      expect(DefenseMap.freshRoom(game.round!.seed), isTrue);
    });

    test('every presence says its content level', () {
      const me = LobbyPresence(
        id: 'a',
        name: 'A',
        colorIndex: 0,
        phase: 'lobby',
        content: GameConfig.contentLevel,
      );
      expect(
        LobbyPresence.fromJson(me.toJson()).content,
        GameConfig.contentLevel,
      );
      expect(
        LobbyPresence.fromJson({...me.toJson()}..remove('content')).content,
        0,
      );
    });
  });

  group('Igel', () {
    test('comes last, needs rank 6 and fires four rockets a salvo', () {
      expect(TankType.values.last, TankType.igel);
      expect(TankType.igel.level, 6);
      expect(muzzlesOf(TankType.igel), hasLength(4));
      final stats = TankStats.of(TankType.igel);
      expect(stats.barrels, 4);
      expect(stats.dps, lessThan(TankStats.of(TankType.wolf).dps));
      expect(
        GameConfig.typeOf(GameConfig.styleOf(TankType.igel.index, 2)),
        TankType.igel,
      );
    });
  });

  group('Igel among the enemies', () {
    test('the fresh mark comes back and keeps map, layout and sky', () {
      for (final seed in seeds) {
        for (final fresh in [true, false]) {
          final base = DefenseMap.seedForLayout(MapTheme.seedFor(seed, 5), 4);
          final marked = DefenseMap.markFresh(base, fresh: fresh);
          expect(DefenseMap.freshRoom(marked), fresh);
          expect(MapTheme.indexOf(marked), 5);
          expect(DefenseMap.layoutFor(marked), 4);
          expect(Conditions.forSeed(marked).sky, Conditions.forSeed(base).sky);
        }
      }
    });

    test('only a fresh room meets the Igel, from wave 6 on', () {
      bool meets(bool igel, int fromWave, int toWave) => [
        for (var wave = fromWave; wave <= toWave; wave++)
          for (var n = 0; n < DefenseMap.waveSize(wave); n++)
            DefenseMap.enemyType(wave, n, igel: igel),
      ].contains(TankType.igel);
      expect(meets(false, 1, 20), isFalse);
      expect(meets(true, 1, 5), isFalse);
      expect(meets(true, 6, 12), isTrue);
    });
  });

  group('comrades by the rules of the waves', () {
    test('in a fresh room a comrade follows its wave, Igel included', () async {
      final game = await loadedGame(net: FakeNet(isHost: true));
      game
        ..chooseMode(GameMode.defense)
        ..startRound(startedAt: DateTime.now().millisecondsSinceEpoch);
      await Future<void>.delayed(Duration.zero);
      final round = game.round!;
      expect(DefenseMap.freshRoom(round.seed), isTrue);
      for (
        var tries = 0;
        tries < 20 && game.botTanks.keys.every((id) => !id.startsWith('ally-'));
        tries++
      ) {
        game.update(0.5);
        await Future<void>.delayed(Duration.zero);
      }
      final allies = game.botTanks.keys.where((id) => id.startsWith('ally-'));
      expect(allies, isNotEmpty);
      for (final id in allies) {
        expect(id, matches(RegExp(r'^ally-\d+-\d+-w\d+$')));
      }
      // The same rule as the enemy's: late waves bring the heavy ones.
      final late = [
        for (var slot = 0; slot < 5; slot++)
          for (var life = 0; life < 4; life++)
            GameConfig.typeOf(round.allyStyle('ally-$slot-$life-w9')),
      ];
      expect(late, contains(TankType.wolf));
      expect(late, contains(TankType.igel));
      expect(
        GameConfig.typeOf(round.allyStyle('ally-2-1-w7')),
        DefenseMap.enemyType(7, 2 + 5, igel: true),
      );
    });

    test(
      'a room with an older client keeps the comrades of their slot',
      () async {
        final game = await loadedGame(net: FakeNet(isHost: true));
        game.chooseMode(GameMode.defense);
        game.net.onRosterChanged?.call([
          const LobbyPresence(
            id: 'old',
            name: 'ALT',
            colorIndex: 0,
            phase: 'lobby',
          ),
        ]);
        game.startRound(startedAt: DateTime.now().millisecondsSinceEpoch);
        await Future<void>.delayed(Duration.zero);
        final round = game.round!;
        expect(DefenseMap.freshRoom(round.seed), isFalse);
        expect(
          GameConfig.typeOf(round.allyStyle('ally-0-0')),
          DefenseMap.allyType(0),
        );
      },
    );
  });
}
