import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/tv/tv_input.dart';

import '../helpers/fakes.dart';

void main() {
  test('the native state reads as kind, sticks and held buttons', () {
    final pad = TvPadState.fromMap({
      'kind': 'gamepad',
      'lx': 0.5,
      'ly': -1,
      'rx': 0,
      'ry': 0.25,
      'r2': true,
      'a': false,
    });
    expect(pad.kind, TvPadKind.gamepad);
    expect((pad.lx, pad.ly, pad.ry), (0.5, -1.0, 0.25));
    expect(pad['r2'], isTrue);
    expect(pad['a'], isFalse);

    expect(TvPadState.fromMap({'kind': 'remote'}).kind, TvPadKind.remote);
    expect(TvPadState.fromMap({'kind': 'none'}).kind, TvPadKind.none);
    expect(TvPadState.fromMap({}).kind, TvPadKind.none);
  });

  test('a stick points on screen with y down and stays inside the circle', () {
    expect(TvSteering.stick(0.1, 0.1, 0.2), isNull);
    final (x, y) = TvSteering.stick(0, 1, 0.2)!;
    expect((x, y), (0.0, -1.0));
    // A corner of a square stick gate is no faster than its edge.
    final (cx, cy) = TvSteering.stick(1, 1, 0.2)!;
    expect(cx * cx + cy * cy, closeTo(1, 1e-9));
    expect(cy, lessThan(0));
  });

  test('every slot has a button and a label', () {
    expect(tvGamepadSlotButtons, hasLength(tvGamepadSlotLabels.length));
  });

  group('back', () {
    TankGame host() => offlineGame(net: FakeNet(isHost: true));

    test('closes the settings, then goes to the start page', () {
      final game = host()..chooseMode(GameMode.solo);
      game.editSettings();
      expect(tvBack(game), isTrue);
      expect(game.configuring.value, isFalse);
      expect(game.choosingMode.value, isFalse);
      expect(tvBack(game), isTrue);
      expect(game.choosingMode.value, isTrue);
    });

    test('leaves the app from the start page', () {
      final game = host();
      expect(game.choosingMode.value, isTrue);
      expect(tvBack(game), isFalse);
    });

    test('leaves the app from a waiting room somebody else hosts', () {
      final game = offlineGame(net: FakeNet(isHost: false))
        ..chooseMode(GameMode.multi);
      expect(game.isHost.value, isFalse);
      expect(tvBack(game), isFalse);
    });

    test('does nothing in a round', () {
      final game = host()..phase.value = GamePhase.playing;
      expect(tvBack(game), isTrue);
      expect(game.phase.value, GamePhase.playing);
    });
  });
}
