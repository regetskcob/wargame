import 'package:flutter/widgets.dart';
import 'package:flutter_deck/flutter_deck.dart';

import '../widgets/repo_qr_card.dart';
import '../widgets/side_bullets.dart';

class TheGameSlide extends FlutterDeckSlideWidget {
  const TheGameSlide()
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/the-game',
          title: 'Panzergefecht, the reference game',
          steps: 5,
          speakerNotes:
              '- This is the finished reference game, everything in it is '
              'built from the parts of today\'s workshop\n'
              '- Scan the QR code and play it right now, it runs on GitHub '
              'Pages against a hosted Supabase project\n'
              '- Four vehicles with their own stats: Leopard 2, Puma, Gepard '
              'and Boxer, and four camouflage schemes\n'
              '- Last tank standing wins, as a free for all or red against '
              'blue, with CPU opponents on top\n'
              '- The terrain is the same for everybody, because it grows '
              'from one shared seed\n'
              '- Nobody has to rebuild it: the skeleton hands you the '
              'drawing code and the sounds, you bring the game',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.split(
      leftBuilder: (context) => const SideBullets(
        useSteps: true,
        items: [
          'Last tank standing: free for all, or red against blue',
          'Leopard 2, Puma, Gepard and Boxer, each with its own stats',
          'Buildings and barriers you can shoot down, woods that slow you',
          'CPU opponents, a closing zone, power-ups and sound',
          'Plays in the browser, scan the code and join in',
        ],
      ),
      rightBuilder: (context) => const Center(
        child: RepoQrCard(
          label: 'Play it',
          url: 'https://www.regetskcob.de/wargame/',
          displayUrl: 'regetskcob.de/wargame',
        ),
      ),
    );
  }
}
