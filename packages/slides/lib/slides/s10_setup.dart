import 'package:flutter/widgets.dart';
import 'package:flutter_deck/flutter_deck.dart';

import '../widgets/code_pane.dart';
import '../widgets/repo_qr_card.dart';

class SetupSlide extends FlutterDeckSlideWidget {
  const SetupSlide()
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/setup',
          title: 'Setting up',
          speakerNotes:
              '- Walk through creating a free project at database.new, pick '
              'a region close to the room\n'
              '- Enable anonymous sign-ins under Authentication settings, '
              'the game signs everyone in anonymously\n'
              '- Point at the QR code, that is the repository to fork, we '
              'connect your fork to Supabase right after installing the CLI\n'
              '- The repository carries the migrations and all the reference '
              'code, so nothing is copied by hand',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.split(
      leftBuilder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FlutterDeckBulletList(
              items: [
                'Create a free project at database.new',
                'Enable anonymous sign-ins under Authentication',
                'Fork the workshop repository on GitHub',
                'Clone your fork and fetch the dependencies',
              ],
            ),
            const SizedBox(height: 40),
            const RepoQrCard(
              label: 'Fork it from here',
              url: 'https://github.com/regetskcob/wargame',
            ),
          ],
        ),
      ),
      rightBuilder: (context) => const CodePane(
        fileName: 'setup.sh',
        code: '''
git clone \\
    https://github.com/your-name/wargame
cd wargame
dart pub get

# What the repository already holds:
#   supabase/migrations/  scores and players tables
#   packages/skeleton/    where you build: tanks, theme
#                         and sounds are already in
#   packages/game/        the finished Panzergefecht''',
      ),
    );
  }
}
