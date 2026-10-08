import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/net/payloads/lobby_presence.dart';

import '../helpers/fakes.dart';

LobbyPresence _pilot(
  String id, {
  int? joined,
  bool owner = false,
  bool pad = false,
}) => LobbyPresence(
  id: id,
  name: id,
  colorIndex: 0,
  phase: 'lobby',
  owner: owner,
  joinedAt: joined,
  pad: pad,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('by default a room holds four pilots within a budget of 400 messages '
      'a second, what the Pro plan carries with a fifth in reserve', () {
    expect(GameConfig.maxPilots, 4);
    expect(GameConfig.realtimeBudget, 400);
    expect(
      GameConfig.roomLoad(4, cpu: true),
      lessThanOrEqualTo(GameConfig.realtimeBudget),
      reason: 'a full room with CPU tanks fits',
    );
    expect(GameConfig.roomLoad(1, cpu: true), 0);
    expect(GameConfig.roomLoad(2, cpu: false), 44);
    expect(GameConfig.roomLoad(2, cpu: true), 70);
    expect(
      GameConfig.roomLoad(2, cpu: false) + GameConfig.padLoad,
      lessThanOrEqualTo(80),
      reason:
          'on the free plan a room of two and a phone fit without CPU '
          'tanks',
    );
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

  const max = GameConfig.maxPilots;

  group('a game in a full room', () {
    test('one pilot too many is turned away and says why', () async {
      final net = FakeNet(isHost: false);
      final game = await loadedGame(net: net);
      game.chooseMode(GameMode.multi);
      net.onRosterChanged!([
        for (var i = 0; i < max; i++) _pilot('p$i', joined: i),
        _pilot('me', joined: net.joinedAt),
      ]);
      expect(game.phase.value, GamePhase.closed);
      expect(game.closedReason.value, contains('voll'));
      expect(net.disposes, 1);
    });

    test(
      'a pilot who was there first stays and sees only a full room',
      () async {
        final net = FakeNet(isHost: false);
        final game = await loadedGame(net: net);
        game.chooseMode(GameMode.multi);
        final me = net.joinedAt;
        net.onRosterChanged!([
          _pilot('me', joined: me),
          for (var i = 0; i < max; i++) _pilot('p$i', joined: me + 1 + i),
        ]);
        expect(game.phase.value, GamePhase.lobby);
        expect(game.roster.value, hasLength(max));
        expect(
          game.roster.value.map((m) => m.id),
          isNot(contains('p${max - 1}')),
        );
        expect(net.disposes, 0);
      },
    );
  });

  group('room slots across the project', () {
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('a pilot alone takes no slot', () async {
      final slots = FakeSlots();
      final net = FakeNet(isHost: true);
      final game = await loadedGame(net: net, slots: slots);
      game.chooseMode(GameMode.multi);
      net.onRosterChanged!([_pilot('me', joined: 1)]);
      await settle();
      expect(slots.claims, isEmpty);
    });

    test('a second pilot in the room takes a slot', () async {
      final slots = FakeSlots();
      final net = FakeNet(isHost: true);
      final game = await loadedGame(net: net, slots: slots);
      game.chooseMode(GameMode.multi);
      net.onRosterChanged!([
        _pilot('me', joined: 1, owner: true),
        _pilot('friend', joined: 2),
      ]);
      await settle();
      expect(slots.claims, [net.room]);
      expect(game.phase.value, GamePhase.lobby);
    });

    test(
      'with every slot taken, who comes in is turned away and says why',
      () async {
        final slots = FakeSlots(free: false);
        final net = FakeNet(isHost: false);
        final game = await loadedGame(net: net, slots: slots);
        game.chooseMode(GameMode.multi);
        net.onRosterChanged!([
          _pilot('host', joined: 1, owner: true),
          _pilot('me', joined: net.joinedAt),
        ]);
        await settle();
        expect(game.phase.value, GamePhase.closed);
        expect(game.closedReason.value, contains('belegt'));
        expect(net.disposes, 1);
      },
    );

    test('the owner of the room stays and waits', () async {
      final slots = FakeSlots(free: false);
      final net = FakeNet(isHost: true);
      final game = await loadedGame(net: net, slots: slots);
      game.chooseMode(GameMode.multi);
      net.onRosterChanged!([
        _pilot('me', joined: 1, owner: true),
        _pilot('guest', joined: 2),
      ]);
      await settle();
      expect(game.phase.value, GamePhase.lobby);
      expect(net.disposes, 0);
    });

    test(
      'a room of two claims what it costs, less with a phone in it',
      () async {
        final slots = FakeSlots();
        final net = FakeNet(isHost: true);
        final game = await loadedGame(net: net, slots: slots);
        game.chooseMode(GameMode.multi);
        net.onRosterChanged!([
          _pilot('me', joined: 1, owner: true),
          _pilot('friend', joined: 2),
        ]);
        await settle();
        expect(slots.claimed.last.$2, 70);

        // The friend pairs a phone: no CPU tanks, room for the phone.
        net.onRosterChanged!([
          _pilot('me', joined: 1, owner: true),
          _pilot('friend', joined: 2, pad: true),
        ]);
        await settle();
        expect(slots.claimed.last.$2, 44);
        expect(game.roomHasPhone, isTrue);
      },
    );

    test(
      'an own phone counts as well, and travels with the presence',
      () async {
        final slots = FakeSlots();
        final net = FakeNet(isHost: true);
        final game = await loadedGame(net: net, slots: slots);
        game.chooseMode(GameMode.multi);
        net.onRosterChanged!([
          _pilot('me', joined: 1, owner: true),
          _pilot('friend', joined: 2),
        ]);
        await settle();
        game.padSteered.value = true;
        await settle();
        expect(slots.claimed.last.$2, 44);
        expect(
          LobbyPresence.fromJson(_pilot('x', pad: true).toJson()).pad,
          true,
        );
      },
    );

    test('in defense the enemies stay CPU tanks, phone or not', () async {
      final slots = FakeSlots();
      final net = FakeNet(isHost: true);
      final game = await loadedGame(net: net, slots: slots);
      game.chooseMode(GameMode.defense);
      net.onRosterChanged!([
        _pilot('me', joined: 1, owner: true),
        _pilot('friend', joined: 2, pad: true),
      ]);
      await settle();
      expect(slots.claimed.last.$2, 70);
    });

    test('a room that held its slot keeps playing when a pilot drops out '
        'and comes back', () async {
      final slots = FakeSlots();
      final net = FakeNet(isHost: false);
      final game = await loadedGame(net: net, slots: slots);
      game.chooseMode(GameMode.multi);
      final pair = [
        _pilot('host', joined: 1, owner: true),
        _pilot('me', joined: net.joinedAt),
      ];
      net.onRosterChanged!(pair);
      await settle();
      // Meanwhile the slot went to another room.
      slots.free = false;
      net
        ..onRosterChanged!([pair.first])
        ..onRosterChanged!(pair);
      await settle();
      expect(game.phase.value, isNot(GamePhase.closed));
    });
  });
}
