import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/net/pad_link.dart';
import 'package:wargame/src/net/payloads/pad_payload.dart';

import '../helpers/fakes.dart';

void main() {
  late PadScreen screen;
  late TankGame main;

  setUp(() {
    screen = PadScreen.instance..clearRoutes();
    main = offlineGame();
    screen
      ..game = main
      ..debugPeers(const []);
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
}
