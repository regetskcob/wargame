// Two real games over a loopback channel, and messages from a client that
// does not play by the rules: anybody with the public key can broadcast
// into any room. Found in the penetration test of issue #12.
@Timeout(Duration(minutes: 2))
library;

import 'package:clock/clock.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/defense/defense_map.dart';
import 'package:wargame/src/game/defense/tower.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/net/inbound_limiter.dart';
import 'package:wargame/src/net/net_events.dart';
import 'package:wargame/src/net/payloads/lobby_presence.dart';

import '../helpers/fakes.dart';

LobbyPresence _member(String id, {bool host = false, bool owner = false}) =>
    LobbyPresence(
      id: id,
      name: id.toUpperCase(),
      colorIndex: 0,
      phase: GamePhase.lobby.name,
      host: host,
      owner: owner,
    );

Future<(TankGame, TankGame)> _room() async {
  final (hostNet, guestNet) = LoopbackNet.pair();
  final host = await loadedGame(net: hostNet);
  final guest = await loadedGame(net: guestNet);
  final roster = [
    _member(host.myId, host: true, owner: true),
    _member(guest.myId),
  ];
  for (final game in [host, guest]) {
    game.net.onRosterChanged?.call(roster);
    game.update(0);
  }
  return (host, guest);
}

Future<void> _start(TankGame host, TankGame guest, GameMode mode) async {
  host.chooseMode(mode);
  final now = clock.now().millisecondsSinceEpoch;
  host.startRound(
    startedAt: mode == GameMode.defense
        ? now - GameConfig.firstWaveSeconds * 1000
        : now - 1,
  );
  await Future<void>.delayed(Duration.zero);
  host.update(0);
  guest.update(0);
}

Future<void> _frames(List<TankGame> games, int count) async {
  for (var i = 0; i < count; i++) {
    for (final game in games) {
      game.update(1 / 30);
    }
    await Future<void>.delayed(Duration.zero);
  }
}

/// A spot beside the road where a gun may stand.
Vector2 _buildSpot(DefenseMap map) {
  final area = DefenseMap.bounds;
  for (var x = area.left; x < area.right; x += 40) {
    for (var y = area.top; y < area.bottom; y += 40) {
      final at = Vector2(x, y);
      if (map.distanceToRoad(at) < DefenseMap.roadHalfWidth + 140 &&
          map.whyNotBuild(at, const []) == null) {
        return at;
      }
    }
  }
  throw StateError('no spot to build');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the inbound limiter', () {
    test('cuts a flood from one sender, not a real game', () {
      withClock(Clock.fixed(DateTime(2026, 10, 10)), () {
        final limiter = InboundLimiter();
        var passed = 0;
        for (var i = 0; i < 1000; i++) {
          if (limiter.admit(NetEvent.shoot, 'eve')) {
            passed++;
          }
        }
        expect(passed, InboundLimiter.senderBurst.toInt());
        // Another player is not held back by the flood.
        expect(limiter.admit(NetEvent.shoot, 'bob'), isTrue);
      });
    });

    test('cuts a flood under made up ids as a whole', () {
      withClock(Clock.fixed(DateTime(2026, 10, 10)), () {
        final limiter = InboundLimiter();
        var passed = 0;
        for (var i = 0; i < 5000; i++) {
          if (limiter.admit(NetEvent.squad, 'td-$i')) {
            passed++;
          }
        }
        expect(passed, (InboundLimiter.rare[NetEvent.squad]! * 2).toInt());
      });
    });

    test('lets ten states a second of a tank through for good', () {
      var now = DateTime(2026, 10, 10);
      withClock(Clock(() => now), () {
        final limiter = InboundLimiter();
        for (var i = 0; i < 600; i++) {
          now = now.add(const Duration(milliseconds: 100));
          expect(limiter.admit(NetEvent.state, 'bob'), isTrue);
        }
      });
    });
  });

  test('a forged round start from 1970 or with a crowd is ignored', () async {
    final net = FakeNet();
    final game = await loadedGame(net: net);
    net.listenWithoutChannel();
    net.deliverForTest(NetEvent.roundStart, {
      'seed': 1,
      'startedAt': 0,
      'participants': ['me', 'eve'],
    });
    expect(game.round, isNull);
    net.deliverForTest(NetEvent.roundStart, {
      'seed': 1,
      'startedAt': clock.now().millisecondsSinceEpoch,
      'participants': ['me', for (var i = 0; i < 500; i++) 'x$i'],
    });
    expect(game.round, isNull);
    expect(game.phase.value, GamePhase.lobby);
  });

  test('a blast without a drone behind it hurts nobody', () async {
    final (host, guest) = await _room();
    await _start(host, guest, GameMode.multi);
    final hp = guest.myTank!.hp;
    final at = guest.myTank!.position;
    for (var i = 0; i < 20; i++) {
      guest.net.deliverForTest(NetEvent.blast, {
        'id': host.myId,
        'blastId': 'fake-$i',
        'weapon': 'mortar',
        'x': at.x,
        'y': at.y,
      });
    }
    await _frames([guest], 3);
    expect(guest.myTank!.hp, hp);
  });

  test('a state with an endless speed or no angle keeps the tank on the '
      'field', () async {
    final (host, guest) = await _room();
    await _start(host, guest, GameMode.multi);
    await _frames([host, guest], 5);
    final tank = guest.remoteTanks[host.myId]!;
    guest.net.deliverForTest(NetEvent.state, {
      'id': host.myId,
      'x': tank.position.x,
      'y': tank.position.y,
      'vx': 1e308,
      'vy': double.infinity,
      'rot': double.nan,
      'hp': 100,
    });
    for (var i = 0; i < 30; i++) {
      tank.update(1 / 30);
    }
    expect(tank.position.x.isFinite && tank.position.y.isFinite, isTrue);
    expect(tank.angle.isFinite, isTrue);
  });

  test('a builder learns that the host destroyed its gun', () async {
    final (host, guest) = await _room();
    await _start(host, guest, GameMode.defense);
    guest.credits.value = 100000;
    guest.myTank!.position.setFrom(_buildSpot(guest.defenseMap!));
    guest.buildTower(TowerKind.values.first);
    await _frames([host, guest], 2);
    final own = guest.towers.values.where((t) => t.ownerId == guest.myId);
    expect(own, hasLength(1));
    final onHost = host.towers[own.single.id]!;
    host.damageTower(onHost, 1e6);
    await _frames([host, guest], 2);
    expect(
      guest.towers.values.where((t) => t.ownerId == guest.myId),
      isEmpty,
      reason: 'the hit came back to the builder as its own echo before',
    );
  });

  test('a death from the round before does not end the new one', () async {
    final (host, guest) = await _room();
    await _start(host, guest, GameMode.multi);
    final round = guest.round!;
    guest.net.deliverForTest(NetEvent.death, {
      'id': host.myId,
      'killerId': guest.myId,
      'round': round.startedAt - 60000,
    });
    expect(round.alive, contains(host.myId));
  });

  test('a player who drops out for a moment keeps the tank', () async {
    final (host, guest) = await _room();
    await _start(host, guest, GameMode.multi);
    await _frames([host, guest], 5);
    // The guest's presence is gone for a moment and the leave arrives,
    // but the guest is still in the roster again when the grace ends.
    host.net.onPeerLeft?.call(guest.myId);
    await _frames([host], 2);
    expect(host.remoteTanks, contains(guest.myId));
    expect(host.round!.alive, contains(guest.myId));
  });

  test('a close in the host\'s name while the host is still there does not '
      'close the room', () async {
    final (host, guest) = await _room();
    guest.net.deliverForTest(NetEvent.close, {'id': host.myId});
    await _frames([guest], 2);
    expect(guest.phase.value, isNot(GamePhase.closed));
  });

  test('call signs lose control and invisible characters and are cut by '
      'whole characters', () {
    expect(cleanCallSign(' \u202Eniam\u200B '), 'niam');
    expect(cleanCallSign('a\nb'), 'ab');
    final emoji = '🪖' * 20;
    final cut = cleanCallSign(emoji);
    expect(cut.runes, hasLength(LobbyPresence.maxName));
    expect(cut, '🪖' * LobbyPresence.maxName);
  });
}
