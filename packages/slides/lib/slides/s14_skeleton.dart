import 'package:flutter/widgets.dart';
import 'package:flutter_deck/flutter_deck.dart';

import '../widgets/code_pane.dart';
import '../widgets/side_bullets.dart';

class SkeletonSlide extends FlutterDeckSlideWidget {
  const SkeletonSlide()
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/skeleton',
          title: 'The skeleton',
          speakerNotes:
              '- Everybody starts from the same place, nobody hand writes a '
              'pubspec today\n'
              '- flame and the v3 prerelease of supabase_flutter are '
              'already resolved\n'
              '- main.dart already initializes Supabase and signs in '
              'anonymously, the status screen turns green once that works, '
              'and it shows the four vehicles and plays the sounds\n'
              '- The drawing code and the sounds are plumbing, not learning: '
              'you spend the workshop on movement and netcode\n'
              '- packages/game is the finished reference, one directory over',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.split(
      leftBuilder: (context) => const SideBullets(
        items: [
          'Start from packages/skeleton',
          'flame and the typesafe v3 prerelease already resolved',
          'Tanks, theme, sounds and tuning constants handed to you',
          'Everything else is what you build',
        ],
      ),
      rightBuilder: (context) => const CodePane(
        fileName: 'packages/skeleton',
        code: '''
skeleton/
  pubspec.yaml    flame, supabase_flutter 3.0.0-dev.9
  assets/audio/   cannon, hit, explosion, engine
  lib/
    main.dart     Supabase init, anonymous sign-in
    src/
      env.dart          url, key, room: fill in
      game_config.dart  tuning constants
      theme.dart        the Bundeswehr look
      audio_service.dart  sound, web and native
      tanks/            four vehicles, drawn in
                        code, with their stats
      app/              placeholder shell

\$ cd packages/skeleton && flutter run -d chrome''',
      ),
    );
  }
}
