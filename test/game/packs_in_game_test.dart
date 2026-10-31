import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/game/weather.dart';
import 'package:wargame/src/store/product.dart';
import 'package:wargame/src/store/shop.dart';

import '../helpers/fakes.dart';

class _Server implements PurchaseServer {
  _Server(this.owns);

  final Set<Product> owns;

  @override
  Future<Set<Product>> owned() async => owns;

  @override
  Future<bool> verify(String store, StorePurchase purchase) async => true;
}

Future<TankGame> _game(Set<Product> owns) async {
  final shop = Shop.closed(server: _Server(owns), signedIn: () => true);
  final game = await loadedGame(shop: shop);
  await shop.refresh();
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('without purchases nobody owns anything', () async {
    final game = await loadedGame();
    expect(game.shop, isNull);
    expect(game.owns(Product.supporter), isFalse);
    game.chooseSupporterPaint(1);
    expect(game.supporterPaint.value, isNull);
  });

  test('the commander sets the opening sky of a round', () async {
    final game = await _game({Product.commander});
    game
      ..skyWish.value = const SkyWish(sky: Sky.fog, night: true)
      ..chooseMode(GameMode.solo)
      ..startRound();
    final seed = game.round!.seed;
    expect(Conditions.forSeed(seed).sky, Sky.fog);
    expect(Conditions.nightAt(seed, 0), isTrue);
  });

  test('a wish without the pack changes nothing', () async {
    final game = await _game({Product.supporter});
    game
      ..skyWish.value = const SkyWish(sky: Sky.fog, night: true)
      ..chooseMode(GameMode.solo)
      ..startRound();
    // The gentle first round, as for everybody.
    expect(Conditions.forSeed(game.round!.seed).sky, Sky.clear);
  });

  test(
    'the supporter drives an exclusive paint and carries the mark',
    () async {
      final game = await _game({Product.supporter});
      game
        ..chooseMode(GameMode.solo)
        ..chooseSupporterPaint(2);
      expect(game.supporterPaint.value, 2);
      expect(
        game.lobbyColorOf(game.myId, game.myColorIndex),
        GameConfig.supporterColors[2],
      );
      game.startRound();
      await game.ready();
      game.update(4);
      final tank = game.myTank!;
      expect(tank.tankColor, GameConfig.supporterColors[2]);
      expect(tank.emblem, isTrue);
    },
  );

  test('with others in the room the paint stays at home', () async {
    final game = await _game({Product.supporter});
    game
      ..chooseMode(GameMode.solo)
      ..chooseSupporterPaint(2)
      ..chooseMode(GameMode.multi);
    expect(
      game.lobbyColorOf(game.myId, game.myColorIndex),
      isNot(GameConfig.supporterColors[2]),
    );
  });

  test('losing the pack loses the paint', () async {
    final game = await _game({});
    game
      ..chooseMode(GameMode.solo)
      ..supporterPaint.value = 2;
    expect(
      game.lobbyColorOf(game.myId, game.myColorIndex),
      GameConfig.colorOf(game.myColorIndex),
    );
  });
}
