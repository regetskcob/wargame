import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/net/payloads/lobby_presence.dart';

import '../helpers/fakes.dart';

// Smoke tests with two real games that hear each other through a loopback
// channel: round start, tank states, shots, hits, deaths, the defense and
// flag state of the host, the end of the round and its replay all cross
// the wire format here, so a message one side sends and the other cannot
// take shows up as a failure.

/// Host and guest in one room, both in the waiting room and seeing each
/// other.
Future<(TankGame, TankGame)> _room() async {
  final (hostNet, guestNet) = LoopbackNet.pair();
  final host = await loadedGame(net: hostNet);
  final guest = await loadedGame(net: guestNet);
  final roster = [
    LobbyPresence(
      id: host.myId,
      name: 'HOST',
      colorIndex: 0,
      phase: GamePhase.lobby.name,
      host: true,
    ),
    LobbyPresence(
      id: guest.myId,
      name: 'GUEST',
      colorIndex: 1,
      phase: GamePhase.lobby.name,
    ),
  ];
  for (final game in [host, guest]) {
    game.net.onRosterChanged?.call(roster);
    game.update(0);
  }
  return (host, guest);
}

/// Plays both games side by side, both tanks circling and firing.
Future<void> _play(List<TankGame> games, {double seconds = 10}) async {
  const dt = 1 / 30;
  for (var frame = 0; frame < seconds / dt; frame++) {
    for (final game in games) {
      game.touch
        ..thrust = true
        ..right = frame % 80 < 25
        ..fire = frame % 3 == 0;
      game.update(dt);
    }
    // Lets the messages of this frame arrive and new tanks finish loading.
    await Future<void>.delayed(Duration.zero);
  }
}

/// The host starts a round of [mode] that the guest joins, past the
/// countdown on both sides.
Future<void> _start(TankGame host, TankGame guest, GameMode mode) async {
  host.chooseMode(mode);
  final now = DateTime.now().millisecondsSinceEpoch;
  host.startRound(
    startedAt: mode == GameMode.defense
        ? now - GameConfig.firstWaveSeconds * 1000
        : now - 1,
  );
  await Future<void>.delayed(Duration.zero);
  host.update(0);
  guest.update(0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a battle of two players runs, ends with a death and replays', () async {
    final (host, guest) = await _room();
    await _start(host, guest, GameMode.multi);
    expect(host.phase.value, GamePhase.playing);
    expect(guest.phase.value, GamePhase.playing);
    expect(guest.round?.seed, host.round?.seed);
    await _play([host, guest]);
    // Each sees the other's tank where it drove.
    expect(host.remoteTanks.keys, contains(guest.myId));
    expect(guest.remoteTanks.keys, contains(host.myId));

    // Down to its last hit points first: the host takes no death from a
    // tank it last saw unharmed.
    guest.myTank!.hp = 1;
    await _play([host, guest], seconds: 1);
    guest.onLocalDeath(host.myId);
    await _play([host, guest], seconds: 1);
    expect(host.phase.value, GamePhase.roundOver);
    expect(host.round?.winnerId, host.myId);

    host.watchReplay();
    expect(host.replaying.value, isTrue);
    await _play([host], seconds: 4);
    host.stopReplay();
    expect(host.phase.value, GamePhase.lobby);
    expect(host.replaying.value, isFalse);
  });

  test('a team battle with CPU tanks on both sides runs', () async {
    final (host, guest) = await _room();
    host
      ..teamMode.value = true
      ..fillWithBots.value = true;
    await _start(host, guest, GameMode.multi);
    expect(host.round?.teamMode, isTrue);
    expect(guest.round?.participants, host.round?.participants);
    expect(guest.round?.bots, host.round?.bots);
    // The host's CPU tanks reach the guest in bundles.
    await _play([host, guest], seconds: 1);
    expect(guest.remoteTanks.keys, containsAll(host.botTanks.keys));
    await _play([host, guest], seconds: 15);
  });

  test('a defense round of two runs on the host and the guest', () async {
    final (host, guest) = await _room();
    await _start(host, guest, GameMode.defense);
    expect(guest.round?.defense, isTrue);
    host.credits.value = guest.credits.value = 100000;
    await _play([host, guest], seconds: 30);
    // The host runs the waves, the guest only hears of them.
    expect(host.defense.value?.wave, greaterThanOrEqualTo(1));
    expect(guest.defense.value?.wave, host.defense.value?.wave);
  });

  test('capture the flag of two runs on the host and the guest', () async {
    final (host, guest) = await _room();
    await _start(host, guest, GameMode.flag);
    expect(guest.round?.flag, isTrue);
    await _play([host, guest], seconds: 15);
    expect(guest.round?.flagHost, host.myId);
  });
}
