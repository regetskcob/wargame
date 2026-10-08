import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/net/payloads/lobby_presence.dart';

import '../helpers/fakes.dart';

LobbyPresence _pilot(String id, {int? joined, bool owner = false}) =>
    LobbyPresence(
      id: id,
      name: id,
      colorIndex: 0,
      phase: 'lobby',
      owner: owner,
      joinedAt: joined,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a room holds four pilots, enough for the Pro plan', () {
    expect(GameConfig.maxPilots, 4);
  });

  group('who stays in a full room', () {
    test('a room that is not full keeps everybody', () {
      final members = [for (var i = 0; i < 4; i++) _pilot('p$i', joined: i)];
      expect(LobbyPresence.admitted(members, 4), members);
    });

    test('the one who came last has to go', () {
      final members = [
        _pilot('late', joined: 50),
        for (var i = 0; i < 4; i++) _pilot('p$i', joined: i),
      ];
      final kept = LobbyPresence.admitted(members, 4).map((m) => m.id);
      expect(kept, ['p0', 'p1', 'p2', 'p3']);
    });

    test('the owner stays, even back from a break', () {
      final members = [
        for (var i = 0; i < 4; i++) _pilot('p$i', joined: i),
        _pilot('owner', joined: 99, owner: true),
      ];
      final kept = LobbyPresence.admitted(members, 4).map((m) => m.id);
      expect(kept, ['p0', 'p1', 'p2', 'owner']);
    });

    test('clients from before the limit count as there first', () {
      final members = [
        for (var i = 0; i < 4; i++) _pilot('p$i', joined: 10 + i),
        _pilot('old'),
      ];
      final kept = LobbyPresence.admitted(members, 4).map((m) => m.id);
      expect(kept, contains('old'));
      expect(kept, isNot(contains('p3')));
    });

    test('every client agrees, whatever order the presences come in', () {
      final members = [
        for (var i = 0; i < 6; i++) _pilot('p$i', joined: i ~/ 2),
      ];
      final one = LobbyPresence.admitted(members, 4).map((m) => m.id).toSet();
      final other = LobbyPresence.admitted(
        members.reversed.toList(),
        4,
      ).map((m) => m.id).toSet();
      expect(one, other);
      expect(one, hasLength(4));
    });

    test('the time of joining travels with the presence', () {
      final back = LobbyPresence.fromJson(_pilot('a', joined: 7).toJson());
      expect(back.joinedAt, 7);
      expect(LobbyPresence.fromJson(_pilot('b').toJson()).joinedAt, isNull);
    });
  });

  group('a game in a full room', () {
    test('the fifth pilot is turned away and says why', () async {
      final net = FakeNet(isHost: false);
      final game = await loadedGame(net: net);
      game.chooseMode(GameMode.multi);
      net.onRosterChanged!([
        for (var i = 0; i < 4; i++) _pilot('p$i', joined: i),
        _pilot('me', joined: net.joinedAt),
      ]);
      expect(game.phase.value, GamePhase.closed);
      expect(game.closedReason.value, contains('voll'));
      expect(net.disposes, 1);
    });

    test('a pilot who was there first stays and sees only four', () async {
      final net = FakeNet(isHost: false);
      final game = await loadedGame(net: net);
      game.chooseMode(GameMode.multi);
      final me = net.joinedAt;
      net.onRosterChanged!([
        _pilot('me', joined: me),
        for (var i = 0; i < 4; i++) _pilot('p$i', joined: me + 1 + i),
      ]);
      expect(game.phase.value, GamePhase.lobby);
      expect(game.roster.value, hasLength(4));
      expect(game.roster.value.map((m) => m.id), isNot(contains('p3')));
      expect(net.disposes, 0);
    });
  });
}
