// The host of a defense round leaves for good: the next player in line runs
// the waves on instead of the base falling for everybody. Three real games
// over a loopback channel. An open point of the penetration test, issue #12.
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
import 'package:wargame/src/net/net_events.dart';
import 'package:wargame/src/net/payloads/defense_payload.dart';
import 'package:wargame/src/net/payloads/lobby_presence.dart';

import '../helpers/fakes.dart';

LobbyPresence _member(String id, {bool host = false}) => LobbyPresence(
  id: id,
  name: id.toUpperCase(),
  colorIndex: 0,
  phase: GamePhase.lobby.name,
  host: host,
  owner: host,
);

/// The host and the guests of one room, the host first.
Future<List<TankGame>> _room(List<String> ids) async {
  final nets = LoopbackNet.group(ids);
  final games = [for (final net in nets) await loadedGame(net: net)];
  final roster = [
    for (final game in games) _member(game.myId, host: game == games.first),
  ];
  for (final game in games) {
    // The grace for a phone that switches networks would only slow the
    // tests down.
    game.peerLeftGrace = Duration.zero;
    game.net.onRosterChanged?.call(roster);
    game.update(0);
  }
  return games;
}

/// Starts a defense round, with the first wave due at once or after the
/// usual wait.
Future<void> _start(List<TankGame> games, {required bool waveDue}) async {
  final host = games.first..chooseMode(GameMode.defense);
  final now = clock.now().millisecondsSinceEpoch;
  host.startRound(
    startedAt: waveDue ? now - GameConfig.firstWaveSeconds * 1000 : now - 1,
  );
  await Future<void>.delayed(Duration.zero);
  for (final game in games) {
    game.update(0);
  }
}

Future<void> _frames(List<TankGame> games, int count) async {
  for (var i = 0; i < count; i++) {
    for (final game in games) {
      game.update(1 / 30);
    }
    await Future<void>.delayed(Duration.zero);
  }
}

/// The host is gone from the channel and the room for good.
Future<void> _hostLeaves(List<TankGame> games) async {
  final host = games.first;
  (host.net as LoopbackNet).cut();
  final stay = games.skip(1).toList();
  final roster = [for (final game in stay) _member(game.myId)];
  for (final game in stay) {
    game.net.onRosterChanged?.call(roster);
    game.net.onPeerLeft?.call(host.myId);
  }
  // The grace runs out.
  await Future<void>.delayed(const Duration(milliseconds: 1));
  await _frames(stay, 2);
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

bool _isEnemy(String id) => id.startsWith('td-');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the next player runs the wave on when the host leaves in the middle '
      'of it, and the round ends the same for everybody', () async {
    final games = await _room(['host', 'guest', 'guestb']);
    final [host, guest, guestB] = games;
    await _start(games, waveDue: true);
    for (var i = 0; i < 900 && !guestB.remoteTanks.keys.any(_isEnemy); i++) {
      await _frames(games, 1);
    }
    final enemies = guest.remoteTanks.keys.where(_isEnemy).toSet();
    expect(enemies, isNotEmpty, reason: 'the first wave rolled in');
    expect(guest.defense.value!.wave, 1);

    await _hostLeaves(games);

    for (final game in [guest, guestB]) {
      expect(game.round!.botHost, guest.myId);
      expect(game.phase.value, GamePhase.playing, reason: game.myId);
      expect(game.defense.value!.result, DefenseResult.running);
      expect(game.defense.value!.hp, greaterThan(0));
    }
    // The new host drives the enemies the old one left behind.
    expect(guest.botTanks.keys.toSet(), containsAll(enemies));
    expect(guest.remoteTanks.keys.where(_isEnemy), isEmpty);
    await _frames([guest, guestB], 60);
    expect(guestB.defense.value!.id, guest.myId);
    expect(
      guestB.remoteTanks.keys.where(_isEnemy),
      isNotEmpty,
      reason: 'the other guest sees the wave the new host runs',
    );

    // Neither the old host coming back nor anybody else speaks for the
    // base: only the new host does.
    final hp = guestB.defense.value!.hp;
    guestB.net.deliverForTest(
      NetEvent.defense,
      DefensePayload(
        id: host.myId,
        hp: 0,
        wave: 9,
        result: DefenseResult.lost,
      ).toJson(),
    );
    guest.net.deliverForTest(
      NetEvent.defense,
      DefensePayload(
        id: guestB.myId,
        hp: 0,
        wave: 9,
        result: DefenseResult.lost,
      ).toJson(),
    );
    await _frames([guest, guestB], 2);
    for (final game in [guest, guestB]) {
      expect(game.phase.value, GamePhase.playing, reason: game.myId);
      expect(game.defense.value!.wave, 1);
    }
    expect(guestB.defense.value!.hp, greaterThanOrEqualTo(hp - 200));

    // The base falls under the new host: lost on both screens.
    guest.damageBase(1e9);
    await _frames([guest, guestB], 5);
    for (final game in [guest, guestB]) {
      expect(game.phase.value, GamePhase.roundOver, reason: game.myId);
      expect(game.outcome.value, RoundOutcome.lost, reason: game.myId);
    }
  });

  test('the new host calls the next wave, keeps the old host\'s gun and the '
      'other guest follows', () async {
    final games = await _room(['host', 'guest', 'guestb']);
    final [host, guest, guestB] = games;
    await _start(games, waveDue: false);
    await _frames(games, 5);
    // The old host built a gun before it went.
    host.credits.value = 100000;
    host.myTank!.position.setFrom(_buildSpot(host.defenseMap!));
    host.buildTower(TowerKind.values.first);
    await _frames(games, 2);
    final gun = host.towers.values
        .where((t) => t.ownerId == host.myId)
        .map((t) => t.id)
        .toList();

    await _hostLeaves(games);

    expect(guest.round!.botHost, guest.myId);
    expect(guest.canCallWave, isTrue);
    expect(guestB.canCallWave, isFalse);
    for (final game in [guest, guestB]) {
      expect(game.towers.keys, containsAll(gun), reason: game.myId);
    }
    guest.callWaveNow();
    for (var i = 0; i < 900 && !guestB.remoteTanks.keys.any(_isEnemy); i++) {
      await _frames([guest, guestB], 1);
    }
    for (final game in [guest, guestB]) {
      expect(game.defense.value!.wave, 1, reason: game.myId);
    }
    expect(guest.botTanks.keys.any(_isEnemy), isTrue);
    expect(guestB.remoteTanks.keys.any(_isEnemy), isTrue);
  });

  test('a host who comes back after a stand-in took over runs the waves '
      'again, and nobody runs them twice', () async {
    // Without keys the smaller id ranks first: the host's.
    final games = await _room(['ahost', 'guest', 'guestb']);
    final [host, guest, guestB] = games;
    await _start(games, waveDue: true);
    for (var i = 0; i < 900 && !guestB.remoteTanks.keys.any(_isEnemy); i++) {
      await _frames(games, 1);
    }
    // The host's channel dropped for longer than the grace: the others
    // count it as gone, while it plays on by itself.
    await _hostLeaves(games);
    expect(guest.round!.botHost, guest.myId);
    expect(host.round!.botHost, host.myId);
    await _frames([guest, guestB], 30);

    // Back on the channel and in the room.
    final nets = [for (final game in games) game.net as LoopbackNet];
    for (final net in nets) {
      net.others
        ..clear()
        ..addAll(nets.where((other) => other != net));
    }
    final roster = [
      for (final game in games) _member(game.myId, host: game == host),
    ];
    for (final game in games) {
      game.net.onRosterChanged?.call(roster);
    }
    await _frames(games, 60);

    for (final game in games) {
      expect(game.round!.botHost, host.myId, reason: game.myId);
      expect(game.defense.value!.id, host.myId, reason: game.myId);
    }
    expect(guest.botTanks.keys.where(_isEnemy), isEmpty);
    expect(
      guest.children.whereType<Component>().where(
        (c) => c.runtimeType.toString() == 'DefenseDirector',
      ),
      isEmpty,
    );
    expect(guestB.remoteTanks.keys.where(_isEnemy), isNotEmpty);
    expect(guestB.defense.value!.hp, host.defense.value!.hp);
  });

  test('after its own channel dropped a game waits longer before it counts '
      'the host as gone', () async {
    final games = await _room(['host', 'guest']);
    final guest = games[1]
      ..peerLeftGrace = const Duration(milliseconds: 1)
      ..outageGrace = const Duration(milliseconds: 300);
    await _start(games, waveDue: false);
    await _frames(games, 5);
    guest.net
      ..dropForTest()
      ..upForTest();

    await _hostLeaves(games);
    expect(guest.round!.botHost, games.first.myId, reason: 'still away');

    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _frames([guest], 2);
    expect(guest.round!.botHost, guest.myId, reason: 'gone for good');
  });

  test('a player alone with the host goes on alone', () async {
    final games = await _room(['host', 'guest']);
    final guest = games[1];
    await _start(games, waveDue: false);
    await _frames(games, 5);

    await _hostLeaves(games);

    expect(guest.round!.botHost, guest.myId);
    expect(guest.phase.value, GamePhase.playing);
    guest.callWaveNow();
    for (var i = 0; i < 900 && !guest.botTanks.keys.any(_isEnemy); i++) {
      await _frames([guest], 1);
    }
    expect(guest.defense.value!.wave, 1);
    expect(guest.botTanks.keys.any(_isEnemy), isTrue);
  });
}
