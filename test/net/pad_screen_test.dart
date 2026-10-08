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

  group('the Realtime budget', () {
    setUp(() => screen.code.value = 'ABCDEFGH');

    test('a phone takes its share and tells the game it steers', () async {
      screen.debugPeers(const [('a', 'Anna')]);
      await screen.debugClaimSlot();
      expect(slots.claimed.last, ('pad-ABCDEFGH', 32, false));
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
      expect(main.padSteered.value, isFalse);

      slots.free = true;
      await screen.debugClaimSlot();
      expect(screen.busy.value, isFalse);
      expect(screen.gameOf('a'), same(main));
    });

    test('a phone in a room with others makes room for itself', () async {
      main
        ..chooseMode(GameMode.multi)
        ..roster.value = const [
          LobbyPresence(id: 'me', name: 'me', colorIndex: 0, phase: 'lobby'),
          LobbyPresence(id: 'x', name: 'x', colorIndex: 0, phase: 'lobby'),
        ];
      slots.free = false;
      screen.debugPeers(const [('a', 'Anna')]);
      await screen.debugClaimSlot();
      expect(slots.claimed.last.$3, isTrue, reason: 'forced');
      expect(screen.busy.value, isFalse);
    });
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
