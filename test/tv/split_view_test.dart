import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/round_state.dart';
import 'package:wargame/src/tv/seats.dart';
import 'package:wargame/src/tv/split_view.dart';

import '../helpers/fakes.dart';

void main() {
  RoundState round({Map<String, int> teams = const {}}) => RoundState(
    seed: 1,
    startedAt: 2,
    participants: const ['me', 'cpu-1'],
    teams: teams,
  );

  test('a half takes its team colour in a round with teams', () {
    // Two players together against CPU tanks: both red, the second half
    // must not be framed in blue.
    final game = offlineGame()..round = round(teams: {'me': 1, 'cpu-1': 2});
    expect(TvSplitView.halfColor(game, 1), GameConfig.teamColors[1]);
  });

  test('a half keeps its own colour without teams', () {
    final game = offlineGame()..round = round();
    expect(TvSplitView.halfColor(game, 1), playerColors[1]);
    expect(TvSplitView.halfColor(offlineGame(), 0), playerColors[0]);
  });
}
