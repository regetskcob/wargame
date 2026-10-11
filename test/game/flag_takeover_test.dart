// Capture the flag when every channel drops at once (the project over its
// message limit): a host that comes back takes the flags back, and a score
// made while its channel was down still reaches the others. Found in the
// local flood test of issue #12.
@Timeout(Duration(minutes: 2))
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/tank_game.dart';
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

Future<List<TankGame>> _room(List<String> ids) async {
  final nets = LoopbackNet.group(ids);
  final games = [for (final net in nets) await loadedGame(net: net)];
  final roster = [
    for (final game in games) _member(game.myId, host: game == games.first),
  ];
  for (final game in games) {
    game.peerLeftGrace = Duration.zero;
    game.net.onRosterChanged?.call(roster);
    game.update(0);
  }
  return games;
}

Future<void> _frames(List<TankGame> games, int count) async {
  for (var i = 0; i < count; i++) {
    for (final game in games) {
      game.update(1 / 30);
    }
    await Future<void>.delayed(Duration.zero);
  }
}

/// Starts a capture the flag round past its countdown.
Future<void> _start(List<TankGame> games) async {
  final host = games.first..chooseMode(GameMode.flag);
  host.startRound(startedAt: clock.now().millisecondsSinceEpoch - 4000);
  await Future<void>.delayed(Duration.zero);
  await _frames(games, 2);
}

/// The host drops off the channel and the room for longer than the grace.
Future<void> _hostDrops(List<TankGame> games) async {
  final host = games.first;
  (host.net as LoopbackNet).cut();
  final stay = games.skip(1).toList();
  final roster = [for (final game in stay) _member(game.myId)];
  for (final game in stay) {
    game.net.onRosterChanged?.call(roster);
    game.net.onPeerLeft?.call(host.myId);
  }
  await Future<void>.delayed(const Duration(milliseconds: 1));
  await _frames(stay, 2);
}

/// Everybody is back on the channel and in the room.
void _back(List<TankGame> games) {
  final nets = [for (final game in games) game.net as LoopbackNet];
  for (final net in nets) {
    net.others
      ..clear()
      ..addAll(nets.where((other) => other != net));
  }
  final roster = [
    for (final game in games) _member(game.myId, host: game == games.first),
  ];
  for (final game in games) {
    game.net.onRosterChanged?.call(roster);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a host who comes back after a stand-in took over runs the flags '
      'again, from its own score', () async {
    // Without keys the smaller id ranks first: the host's.
    final games = await _room(['ahost', 'guest']);
    final [host, guest] = games;
    await _start(games);
    expect(guest.round!.flagHost, host.myId);

    await _hostDrops(games);
    expect(guest.round!.flagHost, guest.myId);
    // Meanwhile the host scored on its own screen.
    host.flagMatch!.score[1] = 2;
    await _frames([host], 5);

    // A tank that went down only comes back after half the respawn time,
    // so a late message does not raise a wreck.
    await Future<void>.delayed(
      Duration(milliseconds: (GameConfig.respawnSeconds * 500).round()),
    );
    _back(games);
    await _frames(games, (GameConfig.flagSyncSeconds * 30).round() + 10);

    expect(guest.round!.flagHost, host.myId);
    expect(guest.flagMatch!.score[1], 2);
    expect(guest.round!.left, isNot(contains(host.myId)));
    // The host's tank is back on the other screen.
    expect(guest.remoteTanks.keys, contains(host.myId));
  });

  test('the last capture made while the host was cut off still ends the '
      'round for the others', () async {
    final games = await _room(['ahost', 'guest']);
    final [host, guest] = games;
    await _start(games);
    (host.net as LoopbackNet).cut();
    final team = host.round!.teamOf(host.myId);
    host.flagMatch!.score[team] = GameConfig.flagCaptures;
    await _frames([host], 2);
    expect(host.phase.value, GamePhase.roundOver);
    await _frames([guest], 2);
    expect(guest.phase.value, isNot(GamePhase.roundOver));

    // The channel is back before the guest counted the host as gone.
    final nets = [host.net as LoopbackNet, guest.net as LoopbackNet];
    nets[0].others.add(nets[1]);
    nets[1].others.add(nets[0]);
    await _frames(games, (GameConfig.flagSyncSeconds * 30).round() + 10);

    expect(guest.phase.value, GamePhase.roundOver);
    expect(guest.round!.winnerTeam, team);
  });
}
