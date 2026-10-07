import 'package:flutter/widgets.dart';
import 'package:flutter_deck/flutter_deck.dart';

import '../widgets/code_pane.dart';
import '../widgets/side_bullets.dart';

class ShipItSlide extends FlutterDeckSlideWidget {
  const ShipItSlide()
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/ship-it',
          title: 'Ship it: GitHub Pages and Supabase',
          speakerNotes:
              '- There is no game server to deploy, that is the whole '
              'point\n'
              '- The game is a static Flutter web build, GitHub Pages '
              'serves it for free\n'
              '- In the repository settings set Pages to GitHub Actions, and '
              'add SUPABASE_URL and SUPABASE_KEY as repository variables\n'
              '- The base path is the repository name, a build without it '
              'shows a blank page\n'
              '- The hosted Supabase project holds the migrations and has '
              'anonymous sign-ins enabled, supabase db push applies them, or '
              'the GitHub integration does\n'
              '- The key is publishable, row level security protects the '
              'data, so the variable is not a secret',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.split(
      leftBuilder: (context) => const SideBullets(
        items: [
          'The game is a static web build: no game server to run',
          'GitHub Pages hosts it, a workflow builds it on every push',
          'Supabase Cloud holds the migrations and the Realtime channels',
          'URL and publishable key travel as repository variables',
        ],
      ),
      rightBuilder: (context) => const CodePane(
        fileName: '.github/workflows/pages.yaml',
        code: '''
- name: Build the game
  run: |
    flutter build web \\
      --base-href "/\${REPO_NAME}/" \\
      --dart-define=SUPABASE_URL="\$SUPABASE_URL" \\
      --dart-define=SUPABASE_KEY="\$SUPABASE_KEY"
  working-directory: packages/game
  env:
    REPO_NAME: \${{ github.event.repository.name }}
    SUPABASE_URL: \${{ vars.SUPABASE_URL }}
    SUPABASE_KEY: \${{ vars.SUPABASE_KEY }}

- uses: actions/upload-pages-artifact@v3
  with:
    path: packages/game/build/web
- uses: actions/deploy-pages@v4''',
      ),
    );
  }
}
