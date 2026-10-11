import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/net/payloads/lobby_presence.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Escape asks, a second Escape takes it back and Enter leaves a solo '
      'round for the waiting room', () async {
    final game = await loadedGame();
    expect(game.handleEscape(LogicalKeyboardKey.escape), isFalse);
    game
      ..update(0)
      ..chooseMode(GameMode.solo)
      ..fillWithBots.value = true
      ..startRound();
    // The countdown runs on the wall clock.
    await Future<void>.delayed(const Duration(seconds: 3, milliseconds: 100));
    game.update(0);
    expect(game.phase.value, GamePhase.playing);

    expect(game.handleEscape(LogicalKeyboardKey.enter), isFalse);
    expect(game.handleEscape(LogicalKeyboardKey.escape), isTrue);
    expect(game.leaveAsked.value, isTrue);
    game.handleEscape(LogicalKeyboardKey.escape);
    expect(game.leaveAsked.value, isFalse);
    expect(game.phase.value, GamePhase.playing);

    game.handleEscape(LogicalKeyboardKey.escape);
    expect(game.handleEscape(LogicalKeyboardKey.enter), isTrue);
    expect(game.phase.value, GamePhase.lobby);
    expect(game.round, isNull);
    expect(game.leaveAsked.value, isFalse);
    expect(game.botTanks, isEmpty);
  });

  // Leaving a round with other people in it takes the one who leaves out of
  // the room ("you left the round"); whoever stays plays the round to its
  // end, after the grace a dropped connection gets.
  for (final leaver in const ['host', 'guest']) {
    test('the $leaver leaves a battle of two: out of the room, the other '
        'plays on to the end', () async {
      final (hostNet, guestNet) = LoopbackNet.pair();
      final host = await loadedGame(net: hostNet);
      final guest = await loadedGame(net: guestNet);
      LobbyPresence member(TankGame game, {bool host = false}) => LobbyPresence(
        id: game.myId,
        name: game.myId.toUpperCase(),
        colorIndex: host ? 0 : 1,
        phase: GamePhase.lobby.name,
        host: host,
      );
      final roster = [member(host, host: true), member(guest)];
      for (final game in [host, guest]) {
        game.net.onRosterChanged?.call(roster);
        game.update(0);
      }
      host
        ..fillWithBots.value = false
        ..chooseMode(GameMode.multi)
        ..startRound(startedAt: clock.now().millisecondsSinceEpoch - 1);
      for (var i = 0; i < 10; i++) {
        host.update(1 / 30);
        guest.update(1 / 30);
        await Future<void>.delayed(Duration.zero);
      }
      expect(host.phase.value, GamePhase.playing);
      expect(guest.phase.value, GamePhase.playing);

      final (gone, stays) = leaver == 'host' ? (host, guest) : (guest, host);
      gone.leaveRound();
      expect(gone.phase.value, GamePhase.closed);
      expect(gone.closedReason.value, 'Du hast die Runde verlassen.');

      // The presence of the one who left goes, the leave arrives.
      stays.net.onRosterChanged?.call(
        roster.where((m) => m.id != gone.myId).toList(),
      );
      stays.net.onPeerLeft?.call(gone.myId);
      stays.update(1 / 30);
      // Within the grace the tank stays, it may be a phone switching
      // networks.
      expect(stays.round!.alive, contains(gone.myId));
      await Future<void>.delayed(
        GameConfig.peerLeftGrace + const Duration(milliseconds: 200),
      );
      for (var i = 0; i < 10; i++) {
        stays.update(1 / 30);
        await Future<void>.delayed(Duration.zero);
      }
      expect(
        stays.round?.alive ?? const <String>{},
        isNot(contains(gone.myId)),
      );
      expect(stays.phase.value, isNot(GamePhase.closed));
      // Alone in the battle now, the one who stayed has won it.
      expect(stays.phase.value, GamePhase.roundOver);
    });
  }
}
