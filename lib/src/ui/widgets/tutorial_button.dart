import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../../game/tank_game.dart';
import '../../l10n/l10n.dart';

/// Opens the tutorial. Until the player went through it once, the button
/// stands out in amber, since the tutorial never opens by itself.
class TutorialButton extends StatelessWidget {
  const TutorialButton({required this.game, super.key});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: game.tutorialDone,
      builder: (context, done, _) => done
          ? TextButton.icon(
              onPressed: game.showTutorial,
              icon: const Icon(Icons.school_outlined, size: HzIconSize.row),
              label: Text(tr('EINWEISUNG', 'BRIEFING')),
            )
          : OutlinedButton.icon(
              onPressed: game.showTutorial,
              icon: const Icon(Icons.school_outlined, size: HzIconSize.row),
              label: Text(tr('EINWEISUNG', 'BRIEFING')),
            ),
    );
  }
}
