import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/app/overlay_ids.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';

import '../helpers/fakes.dart';

void main() {
  final later = DateTime.now().add(const Duration(minutes: 11));

  test('a host left alone on the start page leaves the room quietly and '
      'joins it again with the next step', () {
    final net = FakeNet();
    final game = offlineGame(net: net);
    expect(game.beforeWaitingRoom, isTrue);

    game.closeWhenIdle(now: later);
    expect(game.phase.value, GamePhase.lobby, reason: 'no closed screen');
    expect(game.closedReason.value, isNull);
    expect(game.dozing, isTrue);
    expect(net.disposes, 1);

    // Still dozing: nothing left to close.
    game.closeWhenIdle(now: later);
    expect(net.disposes, 1);

    game.chooseMode(GameMode.solo);
    expect(game.dozing, isTrue, reason: 'still setting up the round');
    game.openWaitingRoom();
    expect(game.dozing, isFalse);
    expect(net.connects, 1);
    expect(game.phase.value, GamePhase.lobby);
  });

  test('a waiting room left alone too long closes and says so', () {
    final net = FakeNet();
    final game = offlineGame(net: net)
      ..onGameResize(Vector2(1280, 720))
      ..chooseMode(GameMode.multi)
      ..openWaitingRoom();
    game.overlays.addEntry(OverlayIds.closed, (_, _) => const SizedBox());
    expect(game.beforeWaitingRoom, isFalse);

    game.closeWhenIdle(now: DateTime.now());
    expect(game.phase.value, GamePhase.lobby);

    game.closeWhenIdle(now: later);
    expect(game.phase.value, GamePhase.closed);
    expect(game.closedReason.value, contains('ohne Aktivität'));
  });

  test('the closed screen leads back to the start page', () async {
    final net = FakeNet();
    final game = offlineGame(net: net)
      ..onGameResize(Vector2(1280, 720))
      ..chooseMode(GameMode.multi)
      ..openWaitingRoom();
    game.overlays
      ..addEntry(OverlayIds.closed, (_, _) => const SizedBox())
      ..addEntry(OverlayIds.lobby, (_, _) => const SizedBox());
    game.closeWhenIdle(now: later);
    expect(game.phase.value, GamePhase.closed);

    await game.backToStart();
    expect(game.phase.value, GamePhase.lobby);
    expect(game.isHost.value, isTrue);
    expect(game.choosingMode.value, isTrue);
    expect(game.closedReason.value, isNull);
  });

  test('the host sets up the round before the waiting room opens', () {
    final game = offlineGame()..chooseMode(GameMode.multi);
    expect(game.configuring.value, isTrue);
    expect(game.beforeWaitingRoom, isTrue, reason: 'not listed yet');

    game.openWaitingRoom();
    expect(game.beforeWaitingRoom, isFalse);

    game.editSettings();
    expect(game.configuring.value, isTrue);
    game.changeMode();
    expect(game.choosingMode.value, isTrue);
  });
}
