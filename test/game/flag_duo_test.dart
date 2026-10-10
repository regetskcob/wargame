import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/flag_match.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/net/net_service.dart';
import 'package:wargame/src/net/payloads/lobby_presence.dart';

import '../helpers/fakes.dart';

/// Two players on one screen, as on the Apple TV: the second game joins the
/// first one's room on this device through a [LocalLink].
Future<(TankGame, TankGame)> _duo() async {
  final hostNet = FakeNet(isHost: true);
  final guestNet = NetService(myId: 'p2', room: hostNet.room, isHost: false);
  LocalLink(hostNet, guestNet);
  final host = await loadedGame(net: hostNet);
  final guest = await loadedGame(net: guestNet);
  host
    ..partner = guest
    ..localGuest = true;
  // What the room's presence would show: both pilots in the waiting room.
  // Without a channel in the test it is handed to both games directly.
  const roster = [
    LobbyPresence(id: 'me', name: 'P1', colorIndex: 0, phase: 'lobby'),
    LobbyPresence(id: 'p2', name: 'P2', colorIndex: 0, phase: 'lobby'),
  ];
  hostNet.onRosterChanged?.call(roster);
  guestNet.onRosterChanged?.call(roster);
  await pumpEventQueue();
  return (host, guest);
}

Future<void> _play(TankGame host, TankGame guest) async {
  host
    ..chooseMode(GameMode.flag)
    ..startRound();
  await pumpEventQueue();
  await Future<void>.delayed(const Duration(seconds: 3, milliseconds: 100));
  host.update(0);
  guest.update(0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('two on one screen capture the flag together by default, the CPU '
      'tanks filling both sides', () async {
    final (host, guest) = await _duo();
    await _play(host, guest);
    final round = host.round!;
    expect(round.flag, isTrue);
    expect(guest.round?.flag, isTrue, reason: 'the second game joins');
    expect(guest.phase.value, GamePhase.playing);
    expect(round.participants, containsAll([host.myId, guest.myId]));
    expect(round.participants, hasLength(GameConfig.flagFillTo));
    expect(host.myTeam, guest.myTeam);
    expect(round.aliveIn(1), round.aliveIn(2));
  });

  test('against each other the two players are on opposite sides', () async {
    final (host, guest) = await _duo();
    host.duoTogether.value = false;
    await _play(host, guest);
    expect(guest.myTeam, FlagMatch.otherTeam(host.myTeam));
    expect(host.round!.aliveIn(1), host.round!.aliveIn(2));
  });

  test('the second player hears the flags of the first one', () async {
    final (host, guest) = await _duo();
    await _play(host, guest);
    final enemy = FlagMatch.otherTeam(host.myTeam);
    host.myTank!.position.setFrom(FlagMatch.baseOf(enemy));
    host.update(1 / 60);
    await pumpEventQueue();
    expect(host.flagMatch!.carriedBy(host.myId), enemy);
    expect(guest.flagMatch!.carriedBy(host.myId), enemy);
  });
}
