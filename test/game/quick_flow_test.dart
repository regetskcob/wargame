import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/app/overlay_ids.dart';
import 'package:wargame/src/db/profile_service.dart';
import 'package:wargame/src/db/supabase_schema.g.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/net/room.dart';

import '../helpers/fakes.dart';

/// A server that has the pilot's profile.
class _Profiles extends FakeProfiles {
  _Profiles(this.row);

  final PlayersRow? row;

  @override
  Future<PlayersRow?> load() async => row;

  @override
  Future<Set<String>> achievements() async => {};
}

/// A server whose score, which the progress needs, does not come.
class _NoScores extends FakeScores {
  @override
  Future<ScoresRow?> myScore() async => throw Exception('timeout');
}

Future<TankGame> _game(ProfileService profiles) async {
  final game = offlineGame(profiles: profiles, scores: _NoScores())
    ..onGameResize(Vector2(1280, 720));
  for (final id in [
    OverlayIds.lobby,
    OverlayIds.countdown,
    OverlayIds.hud,
    OverlayIds.spectator,
    OverlayIds.roundOver,
    OverlayIds.closed,
    OverlayIds.tutorial,
  ]) {
    game.overlays.addEntry(id, (_, _) => const SizedBox());
  }
  // ignore: invalid_use_of_internal_member
  await game.load();
  // ignore: invalid_use_of_internal_member
  game.mount();
  await game.ready();
  game.update(0);
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the call sign kept on the device shows at once, and the server\'s '
      'copy counts even when the progress fails', () async {
    rememberPilot('Keiler-Kalle', GameConfig.styleOf(1, 2));
    final none = await _game(_Profiles(null));
    expect(none.myName, 'Keiler-Kalle');

    final game = await _game(
      _Profiles(
        const PlayersRow({
          'id': 'u',
          'name': 'Panzer-2196',
          'style': 0,
          'created_at': '2026-10-10T00:00:00Z',
        }),
      ),
    );
    // The load runs behind the start page.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(game.myName, 'Panzer-2196');
    expect(storedPilot()?.$1, 'Panzer-2196');
  });

  test('quick start goes straight into a solo round with the short '
      'countdown', () async {
    final game = await loadedGame();
    expect(game.choosingMode.value, isTrue);
    final before = DateTime.now().millisecondsSinceEpoch;
    game.quickStart();
    final after = DateTime.now().millisecondsSinceEpoch;
    expect(game.mode.value, GameMode.solo);
    expect(game.phase.value, GamePhase.countdown);
    const wait = GameConfig.soloCountdownSeconds * 1000;
    expect(
      game.round!.startedAt,
      inInclusiveRange(before + wait, after + wait),
    );
  });

  test('the host calls the next defense wave early', () async {
    final game = await loadedGame();
    game
      ..chooseMode(GameMode.defense)
      ..startRound();
    expect(game.canCallWave, isTrue);
    game.callWaveNow();
    expect(
      game.defense.value!.nextWaveAt,
      lessThanOrEqualTo(DateTime.now().millisecondsSinceEpoch),
    );
    expect(game.canCallWave, isFalse);
  });
}
