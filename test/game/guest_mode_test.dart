import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/net/payloads/lobby_presence.dart';

import '../helpers/fakes.dart';

void main() {
  LobbyPresence host(String? mode) => LobbyPresence(
    id: 'host',
    name: 'HOST',
    colorIndex: 0,
    phase: GamePhase.lobby.name,
    host: true,
    owner: true,
    mode: mode,
  );

  LobbyPresence guestOf(TankGame game) => LobbyPresence(
    id: game.myId,
    name: 'GUEST',
    colorIndex: 1,
    phase: GamePhase.lobby.name,
  );

  test('a guest reads the mode the host picked in the waiting room', () async {
    final guest = await loadedGame(net: FakeNet(isHost: false));
    expect(guest.isHost.value, isFalse);
    guest.net.onRosterChanged?.call([host('flag'), guestOf(guest)]);
    expect(guest.mode.value, GameMode.flag);
    guest.net.onRosterChanged?.call([host('defense'), guestOf(guest)]);
    expect(guest.mode.value, GameMode.defense);
  });

  test(
    'a host without a mode or a solo host leave the guest as it is',
    () async {
      final guest = await loadedGame(net: FakeNet(isHost: false));
      final before = guest.mode.value;
      guest.net.onRosterChanged?.call([host(null), guestOf(guest)]);
      expect(guest.mode.value, before);
      guest.net.onRosterChanged?.call([host('solo'), guestOf(guest)]);
      expect(guest.mode.value, before);
      guest.net.onRosterChanged?.call([host('nonsense'), guestOf(guest)]);
      expect(guest.mode.value, before);
    },
  );

  test('the host sends its mode, guests send none', () async {
    final hostNet = FakeNet(isHost: true);
    final hostGame = await loadedGame(net: hostNet);
    hostGame.chooseMode(GameMode.flag);
    expect(hostNet.presence?.mode, 'flag');
    final guestNet = FakeNet(isHost: false);
    final guest = await loadedGame(net: guestNet);
    guest.chooseMode(GameMode.defense);
    expect(guestNet.presence?.mode, isNull);
  });
}
