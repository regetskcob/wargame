import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/flag_match.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/net/net_events.dart';
import 'package:wargame/src/net/payloads/flag_payload.dart';
import 'package:wargame/src/net/payloads/round_start_payload.dart';

import '../helpers/fakes.dart';

/// Keeps what this client sent.
class _RecordingNet extends FakeNet {
  final sent = <(NetEvent, Map<String, dynamic>)>[];

  @override
  void transmit(NetEvent event, Map<String, dynamic> payload) =>
      sent.add((event, payload));
}

/// A capture the flag round of this host alone with CPU tanks, past the
/// countdown.
Future<(TankGame, _RecordingNet)> _flagRound() async {
  final net = _RecordingNet()..othersPresent = true;
  final game = await loadedGame(net: net);
  game
    ..update(0)
    ..chooseMode(GameMode.flag)
    ..startRound();
  await Future<void>.delayed(const Duration(seconds: 3, milliseconds: 100));
  game.update(0);
  return (game, net);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the round start says whether flags are played', () {
    const payload = RoundStartPayload(
      seed: 1,
      startedAt: 2,
      participants: ['a', 'b'],
      flag: true,
    );
    expect(RoundStartPayload.fromJson(payload.toJson()).flag, isTrue);
    expect(
      RoundStartPayload.fromJson(const {
        'seed': 1,
        'startedAt': 2,
        'participants': ['a'],
      }).flag,
      isFalse,
    );
  });

  test('red against blue paints every tank in its team colour instead of '
      'its camouflage', () async {
    final (game, _) = await _flagRound();
    final round = game.round!;
    expect(
      game.myTank!.tankColor,
      GameConfig.teamColors[round.teamOf(game.myId)],
    );
    for (final MapEntry(:key, :value) in game.botTanks.entries) {
      expect(value.tankColor, GameConfig.teamColors[round.teamOf(key)]);
    }
  });

  test('the lobby shows the team colour and no camouflage when teams are '
      'played', () {
    final game = offlineGame()..chooseMode(GameMode.solo);
    expect(game.teamsAhead, isFalse);
    game.teamMode.value = true;
    expect(game.teamsAhead, isTrue);
    game.setTeamPick(2);
    expect(game.lobbyColorOf(game.myId, 0), GameConfig.teamColors[2]);
    game.setTeamPick(0);
    expect(game.lobbyColorOf(game.myId, 0), GameConfig.teamColors[0]);
  });

  test('a flag round fills two even sides with CPU tanks and starts every '
      'tank at its base, without a closing zone', () async {
    final (game, _) = await _flagRound();
    final round = game.round!;
    expect(game.phase.value, GamePhase.playing);
    expect(round.flag, isTrue);
    expect(round.teamMode, isTrue);
    expect(round.participants, hasLength(GameConfig.flagFillTo));
    expect(round.aliveIn(1), round.aliveIn(2));
    expect(round.flagHost, game.myId);
    expect(game.flagMatch, isNotNull);
    final base = FlagMatch.baseOf(game.myTeam);
    expect(
      game.myTank!.position.distanceTo(base),
      lessThan(GameConfig.flagBaseRadius * 2),
    );
    expect(
      round.safeRadiusAt(round.startedAt + 600 * 1000),
      GameConfig.worldRadius,
    );
  });

  test('bringing the enemy flag home scores and is announced', () async {
    final (game, net) = await _flagRound();
    final me = game.myTank!;
    final enemy = FlagMatch.otherTeam(game.myTeam);
    me.position.setFrom(FlagMatch.baseOf(enemy));
    game.update(1 / 60);
    expect(game.flagMatch!.carriedBy(game.myId), enemy);
    expect(me.carriesFlag, isTrue);
    me.position.setFrom(FlagMatch.baseOf(game.myTeam));
    game.update(1 / 60);
    expect(game.flagMatch!.score[game.myTeam], 1);
    expect(me.carriesFlag, isFalse);
    final actions = [
      for (final (event, json) in net.sent)
        if (event == NetEvent.flag) json['a'],
    ];
    expect(actions, containsAllInOrder(['take', 'capture']));
  });

  test('a destroyed tank comes back at its base, the round goes on', () async {
    final (game, _) = await _flagRound();
    game.myTank!.position.setValues(0, 0);
    game.onLocalDeath(null);
    expect(game.myTank, isNull);
    expect(game.phase.value, GamePhase.playing);
    game.update(GameConfig.respawnSeconds + 0.1);
    final back = game.myTank;
    expect(back, isNotNull);
    expect(
      back!.position.distanceTo(FlagMatch.baseOf(game.myTeam)),
      lessThan(GameConfig.flagBaseRadius * 2),
    );
  });

  test('a destroyed CPU tank comes back as well', () async {
    final (game, _) = await _flagRound();
    final bot = game.botTanks.values.first;
    final id = bot.playerId;
    game.onBotDeath(bot, null);
    expect(game.botTanks.containsKey(id), isFalse);
    game.update(GameConfig.respawnSeconds + 0.1);
    expect(game.botTanks.containsKey(id), isTrue);
    expect(game.round!.alive.contains(id), isTrue);
  });

  test('only the authority moves the flags', () async {
    final (game, net) = await _flagRound();
    final match = game.flagMatch!;
    final forged = FlagMatch()..score[1] = 3;
    net.onFlag?.call(
      FlagPayload.tryParse(
        forged.snapshot('somebody', FlagAction.capture, 2).toJson(),
      )!,
    );
    expect(match.score[1], 0);
    expect(game.phase.value, GamePhase.playing);
  });

  test('three captures end the round for the side that made them', () async {
    final (game, _) = await _flagRound();
    game.flagMatch!.score[game.myTeam] = GameConfig.flagCaptures;
    game.update(1 / 60);
    expect(game.phase.value, GamePhase.roundOver);
    expect(game.round!.winnerTeam, game.myTeam);
    expect(game.outcome.value, RoundOutcome.won);
  });
}
