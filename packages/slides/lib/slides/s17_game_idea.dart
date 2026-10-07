import 'package:flutter/widgets.dart';
import 'package:flutter_deck/flutter_deck.dart';

import '../widgets/side_bullets.dart';

class GameIdeaSlide extends FlutterDeckSlideWidget {
  const GameIdeaSlide()
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/game-idea',
          title: 'What game will you build?',
          steps: 5,
          speakerNotes:
              '- Give everyone a few minutes to pick an idea before we '
              'write any game code\n'
              '- The reference in packages/game is one example, nobody has '
              'to rebuild it\n'
              '- Every technique today works for any game where players '
              'share one world in real time\n'
              '- Steer people toward something small: one screen, one way '
              'to score, one way for a round to end\n'
              '- No idea? Follow the reference game, that is completely '
              'fine',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.blank(
      builder: (context) => const SideBullets(
        useSteps: true,
        items: [
          'Pick any real-time multiplayer game: tag, a racer, an arena '
              'shooter, many-player pong',
          'Who are the players, and what does each one control?',
          'What do they compete over, and how does a round end?',
          'Keep it small: one world, one way to win',
          'No idea yet? Build along with Panzergefecht in packages/game',
        ],
      ),
    );
  }
}
