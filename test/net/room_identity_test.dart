// Who is who in a room: every game speaks with a key, every message
// carries a tag per receiver, and the host is ranked by the server's order
// of the keys (migration 0020). The "room identity" point of the
// penetration test of issue #12.
@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/db/room_registry.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/net/host_rank.dart';
import 'package:wargame/src/net/net_events.dart';
import 'package:wargame/src/net/net_service.dart';
import 'package:wargame/src/net/payloads/lobby_presence.dart';
import 'package:wargame/src/net/payloads/round_start_payload.dart';
import 'package:wargame/src/net/room_key.dart';

import '../helpers/fakes.dart';

LobbyPresence _member(
  String id, {
  bool host = false,
  bool owner = false,
  int? joined,
}) => LobbyPresence(
  id: id,
  name: id.substring(0, 4).toUpperCase(),
  colorIndex: 0,
  phase: GamePhase.lobby.name,
  host: host,
  owner: owner,
  joinedAt: joined,
);

/// Gives every net in [nets] the presences of all, as the channel syncs
/// them, plus [extra] ones from clients that do not play by the rules.
void _sync(
  List<NetService> nets,
  Map<NetService, LobbyPresence> members, {
  List<Map<String, dynamic>> extra = const [],
}) {
  final presences = [
    for (final net in nets) net.trackedForTest(members[net]!),
    ...extra,
  ];
  for (final net in nets) {
    net.syncPresencesForTest(presences);
  }
}

/// The server's order: [owner] owns the room, the rest came in this
/// order.
RoomOrder _order(String owner, List<String> others) {
  final start = DateTime(2026, 10, 11, 12);
  return RoomOrder({
    owner: (joinedAt: start, owner: true),
    for (var i = 0; i < others.length; i++)
      others[i]: (joinedAt: start.add(Duration(seconds: i + 1)), owner: false),
  });
}

/// A message as the wire hands it over.
Map<String, dynamic> _wire(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('tags', () {
    late LoopbackNet a;
    late LoopbackNet b;
    late LoopbackNet c;
    late List<String> heardByB;

    setUp(() {
      a = LoopbackNet.keyed(isHost: true);
      b = LoopbackNet.keyed();
      c = LoopbackNet.keyed();
      a.others.addAll([b, c]);
      for (final net in [a, b, c]) {
        net.listenWithoutChannel();
      }
      heardByB = [];
      b.onClose = heardByB.add;
      _sync(
        [a, b, c],
        {
          a: _member(a.myId, host: true, owner: true),
          b: _member(b.myId),
          c: _member(c.myId),
        },
      );
    });

    test('a message reaches the room with a tag for everybody else', () async {
      a.send(NetEvent.close, {'id': a.myId});
      await Future<void>.delayed(Duration.zero);
      expect(heardByB, [a.myId]);
    });

    test('nobody speaks for a player with a key but that player', () async {
      // Without any tag.
      b.deliverForTest(NetEvent.close, {'id': a.myId});
      // From another player in the room, with valid tags of their own.
      final sealed = <String, dynamic>{};
      c.others.add(_Catch(sealed));
      c.send(NetEvent.close, {'id': a.myId});
      await Future<void>.delayed(Duration.zero);
      expect(sealed[RoomMac.field], isNotNull);
      b.deliverForTest(NetEvent.close, _wire(sealed));
      expect(heardByB, isEmpty);
    });

    test('a copied message does not count twice', () async {
      final caught = <String, dynamic>{};
      a.others
        ..clear()
        ..add(_Catch(caught));
      a.send(NetEvent.close, {'id': a.myId});
      await Future<void>.delayed(Duration.zero);
      b.deliverForTest(NetEvent.close, _wire(caught));
      b.deliverForTest(NetEvent.close, _wire(caught));
      expect(heardByB, hasLength(1));
    });

    test('a changed message loses its tag', () async {
      final caught = <String, dynamic>{};
      a.others
        ..clear()
        ..add(_Catch(caught));
      a.send(NetEvent.close, {'id': a.myId});
      await Future<void>.delayed(Duration.zero);
      b.deliverForTest(NetEvent.shoot, _wire(caught));
      b.deliverForTest(NetEvent.close, _wire({...caught, 'x': 1}));
      expect(heardByB, isEmpty);
    });

    test('a presence with another key does not take over an id', () {
      final posing = RoomKey.generate();
      _sync(
        [a, b, c],
        {
          a: _member(a.myId, host: true, owner: true),
          b: _member(b.myId),
          c: _member(c.myId),
        },
        extra: [
          {..._member(a.myId).toJson(), 'key': posing.encoded},
          // An id without a key next to the one with it.
          _member(a.myId, host: true, owner: true).toJson(),
        ],
      );
      // A copy of a presence makes no doublet either: it cannot speak.
      expect(b.duplicateIds, isEmpty);
      expect(b.isVerified(a.myId), isTrue);
    });

    test('players of older builds still come through without tags', () {
      final heard = <String>[];
      b.onClose = heard.add;
      _sync(
        [a, b, c],
        {
          a: _member(a.myId, host: true, owner: true),
          b: _member(b.myId),
          c: _member(c.myId),
        },
        extra: [_member('0123456789abcdef').toJson()],
      );
      b.deliverForTest(NetEvent.close, {'id': '0123456789abcdef'});
      expect(heard, ['0123456789abcdef']);
      expect(b.isVerified('0123456789abcdef'), isFalse);
    });
  });

  group('ranking', () {
    final owner = (
      id: 'aaaa',
      keyed: true,
      claimsOwner: true,
      claimedJoin: 1760000000000,
    );
    final guest = (
      id: 'bbbb',
      keyed: true,
      claimsOwner: false,
      claimedJoin: 1760000001000,
    );
    // Claims to own the room and to have come first, with a small id.
    final poser = (
      id: '0000',
      keyed: true,
      claimsOwner: true,
      claimedJoin: 1735689600001,
    );
    final old = (
      id: '0001',
      keyed: false,
      claimsOwner: true,
      claimedJoin: 1735689600001,
    );

    test('the owner by the server leads, claims count last', () {
      final order = _order('aaaa', ['bbbb', '0000']);
      expect(rankPilots([poser, guest, owner, old], order), [
        'aaaa',
        'bbbb',
        '0000',
        '0001',
      ]);
    });

    test('without the owner the first to come by the server stands in', () {
      final order = _order('aaaa', ['bbbb', '0000']);
      expect(rankPilots([poser, guest], order).first, 'bbbb');
    });

    test('a key the server does not know ranks after those it knows', () {
      final order = _order('aaaa', ['bbbb']);
      expect(rankPilots([poser, guest], order).first, 'bbbb');
    });

    test('a room of an older build keeps its owner', () {
      final order = _order('cccc', [])..pilots.clear();
      final oldOwner = (
        id: 'ffff',
        keyed: false,
        claimsOwner: true,
        claimedJoin: 1760000000000,
      );
      expect(rankPilots([guest, oldOwner], order).first, 'ffff');
      // Not once the room belongs to an account.
      expect(
        rankPilots([guest, oldOwner], _order('cccc', ['bbbb'])).first,
        'bbbb',
      );
    });
  });

  group('three games', () {
    late List<TankGame> games;
    late TankGame owner;
    late TankGame guest;
    late TankGame poser;

    Future<void> frames(int count, [double dt = 1 / 30]) async {
      for (var i = 0; i < count; i++) {
        for (final game in games) {
          game.update(dt);
        }
        await Future<void>.delayed(Duration.zero);
      }
    }

    setUp(() async {
      final nets = [
        LoopbackNet.keyed(isHost: true),
        LoopbackNet.keyed(),
        LoopbackNet.keyed(),
      ];
      for (final net in nets) {
        net.others.addAll(nets.where((other) => other != net));
      }
      games = [for (final net in nets) await loadedGame(net: net)];
      [owner, guest, poser] = games;
      final now = clock.now().millisecondsSinceEpoch;
      final order = _order(owner.myId, [guest.myId, poser.myId]);
      for (final net in nets) {
        net.order = order;
      }
      _sync(nets, {
        nets[0]: _member(owner.myId, host: true, owner: true, joined: now),
        nets[1]: _member(guest.myId, joined: now + 1000),
        // Poses as the owner who came first.
        nets[2]: _member(
          poser.myId,
          host: true,
          owner: true,
          joined: 1735689600001,
        ),
      });
      // The poser's own game believes its claim.
      poser.isHost.value = true;
      await frames(1);
    });

    test(
      'the owner keeps the host role against a player posing as it',
      () async {
        await frames(5, 1);
        for (final game in games) {
          expect(game.rightfulHost, owner.myId, reason: game.myName);
        }
        expect(owner.isHost.value, isTrue);
        expect(guest.isHost.value, isFalse);
        // The poser's own game steps down too.
        expect(poser.isHost.value, isFalse);
      },
    );

    test('a round start or a close from the poser changes nothing', () async {
      final now = clock.now().millisecondsSinceEpoch;
      poser.net.send(
        NetEvent.roundStart,
        RoundStartPayload(
          seed: 7,
          startedAt: now,
          participants: [owner.myId, guest.myId, poser.myId],
        ).toJson(),
      );
      poser.net.send(NetEvent.close, {'id': poser.myId});
      await frames(3);
      expect(guest.phase.value, GamePhase.lobby);
      expect(guest.round, isNull);
    });

    test('a round of the owner runs on every screen', () async {
      owner.chooseMode(GameMode.multi);
      owner.startRound(startedAt: clock.now().millisecondsSinceEpoch - 1);
      await frames(3);
      expect(guest.round?.seed, owner.round?.seed);
      expect(poser.round?.seed, owner.round?.seed);
      expect(guest.phase.value, isNot(GamePhase.lobby));
    });

    test('only the runner of the CPU tanks speaks for them', () async {
      owner.chooseMode(GameMode.multi);
      owner.startRound(startedAt: clock.now().millisecondsSinceEpoch - 1);
      await frames(3);
      expect(guest.round, isNotNull);
      // Without CPU tanks in the round the host runs whatever comes.
      expect(guest.round!.botHost ?? guest.rightfulHost, owner.myId);
      const bot = 'cpu-1';
      final admits = guest.net.admits!;
      expect(admits(NetEvent.shoot, bot, owner.myId), isTrue);
      expect(admits(NetEvent.shoot, bot, poser.myId), isFalse);
      // Without a tag, while the runner speaks with a key.
      expect(admits(NetEvent.shoot, bot, null), isFalse);
      expect(admits(NetEvent.shoot, poser.myId, poser.myId), isTrue);
    });

    test('without the server the presences settle the room as before', () {
      for (final game in games) {
        game.net.order = null;
        expect(game.rightfulHost, isNull);
      }
    });
  });
}

/// Keeps the last message sent to it, as somebody listening on the
/// channel would.
class _Catch extends LoopbackNet {
  _Catch(this.caught) : super('catch');

  final Map<String, dynamic> caught;

  @override
  void deliverForTest(NetEvent event, Map<String, dynamic> json) {
    caught
      ..clear()
      ..addAll(json);
  }
}
