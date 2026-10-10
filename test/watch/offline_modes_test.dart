import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/net/net_service.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final mode in GameMode.values) {
    test(
      'the watch plays ${mode.name} alone, without a room channel',
      () async {
        final net = NetService(myId: 'me', room: 'WATCH', offline: true);
        final game = await loadedGame(net: net);
        game.chooseMode(mode);
        expect(game.canStart, isTrue);
        game.startRound(startedAt: clock.now().millisecondsSinceEpoch);
        await Future<void>.delayed(Duration.zero);
        game.update(0);
        expect(game.phase.value, GamePhase.playing);
        if (mode != GameMode.defense) {
          expect(game.botTanks, isNotEmpty, reason: 'CPU tanks fill the field');
        }
      },
    );
  }
}
