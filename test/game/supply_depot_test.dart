import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/bot_level.dart';
import 'package:wargame/src/game/components/supply_depot.dart';
import 'package:wargame/src/game/flag_match.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/net/net_events.dart';
import 'package:wargame/src/net/payloads/obstacle_payload.dart';

import '../helpers/fakes.dart';

class _RecordingNet extends FakeNet {
  final sent = <(NetEvent, Map<String, dynamic>)>[];

  @override
  void transmit(NetEvent event, Map<String, dynamic> payload) =>
      sent.add((event, payload));
}

/// A round of this host with CPU tanks, past the countdown and with the
/// depots standing.
Future<(TankGame, _RecordingNet)> _round(
  GameMode mode, {
  BotLevel level = BotLevel.normal,
}) async {
  final net = _RecordingNet()..othersPresent = true;
  final game = await loadedGame(net: net);
  game
    ..update(0)
    ..chooseMode(mode);
  game.botLevel.value = level;
  game.fillWithBots.value = true;
  game.startRound();
  await Future<void>.delayed(const Duration(seconds: 3, milliseconds: 100));
  for (var i = 0; i < 3; i++) {
    game.update(0);
    await Future<void>.delayed(Duration.zero);
  }
  return (game, net);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('layout', () {
    test('a free for all gets neutral fuel and ammo by turns on a ring, the '
        'same for the same seed', () {
      final spots = SupplyField.layout(seed: 42, flag: false);
      expect(spots, hasLength(GameConfig.depotCount));
      expect(spots.map((s) => s.team).toSet(), {0});
      expect(spots.map((s) => s.kind), [
        DepotKind.fuel,
        DepotKind.ammo,
        DepotKind.fuel,
        DepotKind.ammo,
      ]);
      for (final spot in spots) {
        expect(
          spot.position.length,
          inInclusiveRange(GameConfig.depotRingMin, GameConfig.depotRingMax),
        );
      }
      final again = SupplyField.layout(seed: 42, flag: false);
      expect(
        [for (final s in again) s.position],
        [for (final s in spots) s.position],
      );
    });

    test('capture the flag gives each team a pair behind its base', () {
      final spots = SupplyField.layout(seed: 7, flag: true);
      for (final team in const [1, 2]) {
        final own = spots.where((s) => s.team == team).toList();
        expect(own.map((s) => s.kind).toSet(), DepotKind.values.toSet());
        for (final spot in own) {
          final base = FlagMatch.baseOf(team);
          // Further out than the base, on the far side from the middle.
          expect(spot.position.x.abs(), greaterThan(base.x.abs()));
          expect(spot.position.distanceTo(base), lessThan(260));
        }
      }
    });

    test('depots move off a building that stands in the way', () {
      final wanted = SupplyField.layout(seed: 3, flag: false);
      final first = wanted.first.position;
      final building = Rect.fromCenter(
        center: Offset(first.x, first.y),
        width: 80,
        height: 60,
      );
      final moved = SupplyField.layout(
        seed: 3,
        flag: false,
        solids: [building],
      ).first.position;
      expect(
        building
            .inflate(GameConfig.depotRadius * 0.7)
            .contains(Offset(moved.x, moved.y)),
        isFalse,
      );
    });
  });

  test('the easy level has no depots', () async {
    final (game, _) = await _round(GameMode.solo, level: BotLevel.easy);
    expect(game.depots, isEmpty);
  });

  test('a tank standing on a fuel station fills up', () async {
    final (game, _) = await _round(GameMode.solo);
    final station = game.depots.firstWhere((d) => d.kind == DepotKind.fuel);
    final me = game.myTank!;
    expect(me.usesFuel, isTrue);
    me
      ..position.setFrom(station.position)
      ..setFuel(0.2);
    game.update(1);
    expect(me.fuel, closeTo(0.2 + 1 / GameConfig.depotFillSeconds, 0.05));
  });

  test('in capture the flag only the own team fills up, and only the enemy '
      'can shoot a depot', () async {
    final (game, _) = await _round(GameMode.flag);
    final me = game.myTank!;
    final enemy = FlagMatch.otherTeam(game.myTeam);
    final own = game.depots.firstWhere(
      (d) => d.team == game.myTeam && d.kind == DepotKind.fuel,
    );
    final theirs = game.depots.firstWhere(
      (d) => d.team == enemy && d.kind == DepotKind.fuel,
    );
    expect(own.serves(game.myTeam), isTrue);
    expect(theirs.serves(game.myTeam), isFalse);
    expect(game.hurtsDepot(game.myId, own), isFalse);
    expect(game.hurtsDepot(game.myId, theirs), isTrue);

    me
      ..position.setFrom(theirs.position)
      ..setFuel(0.2);
    game.update(1);
    expect(me.fuel, lessThanOrEqualTo(0.2));
  });

  test('a depot shot down goes up, hurts tanks close by, tells the others '
      'and stands again later', () async {
    final (game, net) = await _round(GameMode.solo);
    final depot = game.depots.first;
    final me = game.myTank!;
    me.position.setFrom(depot.position + Vector2(40, 0));
    final hp = me.hp;
    game.damageDepot(depot, GameConfig.depotHp, 'bot-x');
    expect(depot.destroyed, isTrue);
    expect(me.hp, lessThan(hp));
    final message = net.sent.lastWhere((m) => m.$1 == NetEvent.obstacle).$2;
    final payload = ObstaclePayload.fromJson(message);
    expect(payload.depot, isTrue);
    expect(payload.index, depot.index);
    expect(payload.hp, 0);

    // A destroyed depot serves nobody until it is rebuilt.
    expect(depot.serves(0), isFalse);
    game.update(GameConfig.depotRebuildSeconds / 2);
    game.update(GameConfig.depotRebuildSeconds / 2 + 0.1);
    expect(depot.destroyed, isFalse);
    expect(depot.hp, GameConfig.depotHp);
  });

  test(
    'news from another client takes a depot down or puts it back up',
    () async {
      final (game, net) = await _round(GameMode.solo);
      final depot = game.depots.first;
      net.onObstacle!(
        ObstaclePayload(id: 'p2', index: depot.index, hp: 0, depot: true),
      );
      expect(depot.destroyed, isTrue);
      // A late hit on the ruin changes nothing.
      net.onObstacle!(
        ObstaclePayload(id: 'p2', index: depot.index, hp: 0, depot: true),
      );
      expect(depot.destroyed, isTrue);
      // The other client rebuilt it and hit it again.
      net.onObstacle!(
        ObstaclePayload(id: 'p2', index: depot.index, hp: 90, depot: true),
      );
      expect(depot.destroyed, isFalse);
      expect(depot.hp, 90);
    },
  );
}
