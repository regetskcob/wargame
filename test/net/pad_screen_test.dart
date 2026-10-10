import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/net/pad_link.dart';
import 'package:wargame/src/net/payloads/lobby_presence.dart';
import 'package:wargame/src/net/payloads/pad_payload.dart';

import '../helpers/fakes.dart';

void main() {
  late PadScreen screen;
  late TankGame main;
  late FakeSlots slots;

  setUp(() {
    screen = PadScreen.instance..clearRoutes();
    slots = FakeSlots();
    main = offlineGame(slots: slots);
    screen
      ..game = main
      ..debugPeers(const []);
  });

  tearDown(() {
    screen
      ..code.value = null
      ..busy.value = false
      ..onSend = null;
  });

  Map<String, dynamic> push(String id) =>
      const PadInput(id: '', drive: (0, -1)).toJson()..['id'] = id;

  test('the first phone steers, a second one waits', () {
    screen.debugPeers(const [('a', 'Anna'), ('b', 'Ben')]);
    expect(screen.paired.value, 'Anna');
    expect(screen.gameOf('a'), same(main));
    expect(screen.gameOf('b'), isNull);

    screen.debugPadInput(push('b'));
    expect(main.touch.drive, isNull);
    screen.debugPadInput(push('a'));
    expect(main.touch.drive, (0.0, -1.0));
    expect(screen.steers(main), isTrue);
  });

  test('the second phone moves up when the first leaves', () {
    screen
      ..debugPeers(const [('a', 'Anna'), ('b', 'Ben')])
      ..debugPeers(const [('b', 'Ben')]);
    expect(screen.paired.value, 'Ben');
    expect(screen.gameOf('b'), same(main));
  });

  test('a duel hands each phone a half of its own', () {
    final left = offlineGame();
    final right = offlineGame();
    screen
      ..debugPeers(const [('a', 'Anna'), ('b', 'Ben')])
      ..route('a', left)
      ..route('b', right);
    expect(screen.gameOf('a'), same(left));
    expect(screen.gameOf('b'), same(right));
    // The game behind the duel waits meanwhile.
    expect(screen.steers(main), isFalse);

    screen.debugPadInput(push('b'));
    expect(right.touch.drive, (0.0, -1.0));
    expect(left.touch.drive, isNull);

    screen.clearRoutes();
    expect(screen.gameOf('a'), same(main));
  });

  test(
    'handing out the same routes again changes and claims nothing',
    () async {
      final left = offlineGame(slots: slots);
      screen
        ..code.value = 'ABCDEFGH'
        ..debugPeers(const [('a', 'Anna')])
        ..route('a', left);
      await Future<void>.delayed(Duration.zero);
      final claims = slots.claims.length;
      var changes = 0;
      void count() => changes++;
      left.padSteered.addListener(count);
      // The second player on an iPad hands the seats out with every change
      // of the roster; the same seats again must not set anything off, or it
      // runs in circles.
      screen.route('a', left);
      screen
        ..clearRoutes()
        ..clearRoutes();
      await Future<void>.delayed(Duration.zero);
      left.padSteered.removeListener(count);
      expect(changes, 1, reason: 'only the one real clear');
      expect(slots.claims.length, claims + 1);
    },
  );

  test('a game may route the phones again while they are cleared', () {
    final left = offlineGame();
    final right = offlineGame();
    screen
      ..debugPeers(const [('a', 'Anna'), ('b', 'Ben')])
      ..route('a', left)
      ..route('b', right);
    // Like the Apple TV's second player, which hands the phones out anew
    // when the lobby hears that a game lost its phone.
    var again = true;
    void reroute() {
      if (again && !left.padSteered.value) {
        again = false;
        screen
          ..clearRoutes()
          ..route('a', right);
      }
    }

    left.padSteered.addListener(reroute);
    screen.clearRoutes();
    left.padSteered.removeListener(reroute);
    expect(screen.gameOf('a'), same(right));
    expect(right.padSteered.value, isTrue);
  });

  group('the Realtime budget', () {
    setUp(() => screen.code.value = 'ABCDEFGH');

    test('a phone takes its share and tells the game it steers', () async {
      screen.debugPeers(const [('a', 'Anna')]);
      await screen.debugClaimSlot();
      expect(slots.claimed.last, ('pad-ABCDEFGH', 32));
      expect(main.padSteered.value, isTrue);
    });

    test('a duel with two phones takes two shares', () async {
      final left = offlineGame(slots: slots);
      final right = offlineGame(slots: slots);
      screen
        ..debugPeers(const [('a', 'Anna'), ('b', 'Ben')])
        ..route('a', left)
        ..route('b', right);
      await screen.debugClaimSlot();
      expect(slots.claimed.last.$2, 64);
      expect(left.padSteered.value && right.padSteered.value, isTrue);
      expect(main.padSteered.value, isFalse);
    });

    test('without room in the budget the phones wait and say so', () async {
      slots.free = false;
      screen.debugPeers(const [('a', 'Anna')]);
      await screen.debugClaimSlot();
      expect(screen.busy.value, isTrue);
      expect(screen.gameOf('a'), isNull);
      // Still paired: the room keeps playing without CPU tanks for it.
      expect(main.padSteered.value, isTrue);

      slots.free = true;
      await screen.debugClaimSlot();
      expect(screen.busy.value, isFalse);
      expect(screen.gameOf('a'), same(main));
    });

    test(
      'a room with others lowers its slot before the phone claims',
      () async {
        main
          ..chooseMode(GameMode.multi)
          ..roster.value = const [
            LobbyPresence(id: 'me', name: 'me', colorIndex: 0, phase: 'lobby'),
            LobbyPresence(id: 'x', name: 'x', colorIndex: 0, phase: 'lobby'),
          ];
        screen.debugPeers(const [('a', 'Anna')]);
        await screen.debugClaimSlot();
        final room = slots.claimed.lastIndexWhere((c) => c.$1 == main.net.room);
        final pad = slots.claimed.lastIndexWhere((c) => c.$1 == 'pad-ABCDEFGH');
        expect(slots.claimed[room].$2, 44, reason: 'no CPU tanks with a phone');
        expect(room, lessThan(pad));
        expect(slots.claimed[pad].$2, 32);
      },
    );

    test(
      'in defense the room keeps its CPU tanks and the phone may wait',
      () async {
        main
          ..chooseMode(GameMode.defense)
          ..roster.value = const [
            LobbyPresence(id: 'me', name: 'me', colorIndex: 0, phase: 'lobby'),
            LobbyPresence(id: 'x', name: 'x', colorIndex: 0, phase: 'lobby'),
          ];
        screen.debugPeers(const [('a', 'Anna')]);
        await screen.debugClaimSlot();
        final room = slots.claimed.lastWhere((c) => c.$1 == main.net.room);
        expect(room.$2, 70);
      },
    );
  });

  group('lanes', () {
    test('the status goes on the lane of its phone', () {
      final sent = <(String, String?)>[];
      screen
        ..onSend = (event, payload, lane) {
          sent.add((event, lane));
        }
        ..debugPeers(const [('a', 'Anna')], lanes: {'a'})
        ..debugTick();
      expect(sent, [('status', 'a')]);
    });

    test('a phone from before lanes hears it on the shared channel', () {
      final sent = <(String, String?)>[];
      screen
        ..onSend = (event, payload, lane) {
          sent.add((event, lane));
        }
        ..debugPeers(const [('a', 'Anna')])
        ..debugTick();
      expect(sent, [('status', null)]);
    });

    test('a phone talks on its own lane once the screen has lanes', () {
      final remote = PadRemote('ABCDEFGH');
      final lanes = <String?>[];
      remote
        ..onSend = (event, payload, lane) {
          lanes.add(lane);
        }
        ..debugScreen(lanes: true)
        ..tick()
        ..act(PadActionKind.item);
      expect(lanes, [remote.id, remote.id]);

      remote.debugScreen(lanes: false);
      remote.act(PadActionKind.item);
      expect(lanes.last, isNull);
    });
  });
}
