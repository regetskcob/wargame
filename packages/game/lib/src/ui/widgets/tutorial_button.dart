import 'package:flutter/material.dart';

import '../../game/space_game.dart';
import '../../theme.dart';

/// Opens the tutorial. Until the player went through it once, the button
/// stands out in amber, since the tutorial never opens by itself.
class TutorialButton extends StatelessWidget {
  const TutorialButton({required this.game, super.key});

  final SpaceGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: game.tutorialDone,
      builder: (context, done, _) => done
          ? TextButton.icon(
              onPressed: game.showTutorial,
              icon: const Icon(Icons.school, size: 18),
              label: const Text('EINWEISUNG ANSEHEN'),
            )
          : OutlinedButton.icon(
              onPressed: game.showTutorial,
              style: OutlinedButton.styleFrom(
                foregroundColor: BwColors.amber,
                side: const BorderSide(color: BwColors.amber, width: 1.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Icons.school, size: 18),
              label: const Text('NEU HIER? EINWEISUNG ANSEHEN'),
            ),
    );
  }
}
