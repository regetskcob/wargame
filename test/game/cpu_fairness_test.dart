import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/components/tank_painter.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/net/payloads/lobby_presence.dart';

import '../helpers/fakes.dart';

LobbyPresence _red(String id, [TankType type = TankType.keiler]) =>
    LobbyPresence(
      id: id,
      name: id.toUpperCase(),
      colorIndex: GameConfig.styleOf(type.index, 0),
      phase: 'lobby',
      team: 1,
      content: GameConfig.contentLevel,
    );

Future<TankGame> _host(
  List<String> others, {
  Map<String, TankType> vehicles = const {},
}) async {
  final game = await loadedGame(net: FakeNet(isHost: true));
  game.net.onRosterChanged?.call([
    for (final id in others) _red(id, vehicles[id] ?? TankType.keiler),
  ]);
  game.setTeamPick(1);
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<int, int> sizes(TankGame game) {
    final teams = <int, int>{};
    for (final id in game.round!.participants) {
      final team = game.round!.teamOf(id);
      teams[team] = (teams[team] ?? 0) + 1;
    }
    return teams;
  }

  test('CPU tanks even out a battle where everybody picked red', () async {
    final game = await _host(['b', 'c']);
    game
      ..chooseMode(GameMode.multi)
      ..teamMode.value = true
      ..fillWithBots.value = true
      ..startRound(startedAt: DateTime.now().millisecondsSinceEpoch);
    final teams = sizes(game);
    expect(teams[1], 3);
    expect(teams[2], 3, reason: 'not 3 against 1');
  });

  test('and a flag round where everybody picked red', () async {
    final game = await _host(['b', 'c', 'd']);
    game
      ..chooseMode(GameMode.flag)
      ..startRound(startedAt: DateTime.now().millisecondsSinceEpoch);
    final teams = sizes(game);
    expect(teams[1], teams[2]);
  });

  test('both sides get the same CPU vehicles, pair by pair', () async {
    for (var i = 0; i < 20; i++) {
      final game = await _host(const []);
      game
        ..chooseMode(GameMode.flag)
        ..startRound(startedAt: DateTime.now().millisecondsSinceEpoch);
      final round = game.round!;
      List<String> side(int team) => [
        for (final id in round.bots.keys.toList()..sort())
          if (round.teamOf(id) == team) id,
      ];
      final red = side(1);
      final blue = side(2);
      for (var n = 0; n < red.length && n < blue.length; n++) {
        expect(
          GameConfig.typeOf(round.bots[red[n]]!),
          GameConfig.typeOf(round.bots[blue[n]]!),
        );
      }
    }
  });

  Set<TankType> cpuVehicles(TankGame game) => {
    for (final style in game.round!.bots.values) GameConfig.typeOf(style),
  };

  test('alone, every CPU tank drives the player\'s vehicle', () async {
    for (final type in TankType.values) {
      final game = await loadedGame()
        ..myColorIndex = GameConfig.styleOf(type.index, 2)
        ..chooseMode(GameMode.solo)
        ..startRound(startedAt: DateTime.now().millisecondsSinceEpoch);
      expect(game.round!.bots, isNotEmpty);
      expect(cpuVehicles(game), {type}, reason: type.name);
    }
  });

  test('a new player in a starter meets starters only', () async {
    for (var i = 0; i < 10; i++) {
      final game = await loadedGame()
        ..chooseMode(GameMode.solo)
        ..startRound(startedAt: DateTime.now().millisecondsSinceEpoch);
      for (final type in cpuVehicles(game)) {
        expect(type.level, 1);
      }
    }
  });

  test('with several people, CPU tanks draw from what they drive', () async {
    final seen = <TankType>{};
    for (var i = 0; i < 30; i++) {
      final game = await _host(
        ['b', 'c'],
        vehicles: {'b': TankType.wolf, 'c': TankType.igel},
      );
      game
        ..myColorIndex = GameConfig.styleOf(TankType.hermelin.index, 0)
        ..chooseMode(GameMode.multi)
        ..fillWithBots.value = true
        ..startRound(startedAt: DateTime.now().millisecondsSinceEpoch);
      final types = cpuVehicles(game);
      expect(
        types.difference({TankType.hermelin, TankType.wolf, TankType.igel}),
        isEmpty,
      );
      seen.addAll(types);
    }
    expect(seen, {TankType.hermelin, TankType.wolf, TankType.igel});
  });

  test('in a flag round both sides mirror the people pair by pair', () async {
    for (var i = 0; i < 10; i++) {
      final game = await _host(['b'], vehicles: {'b': TankType.dachs});
      game
        ..myColorIndex = GameConfig.styleOf(TankType.wolf.index, 0)
        ..chooseMode(GameMode.flag)
        ..startRound(startedAt: DateTime.now().millisecondsSinceEpoch);
      expect(
        cpuVehicles(game).difference({TankType.wolf, TankType.dachs}),
        isEmpty,
      );
    }
  });
}
