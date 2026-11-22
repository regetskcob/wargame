import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../../game/tank_game.dart';
import '../../l10n/l10n.dart';

/// Where a [TutorialButton] stands on a page that shows it twice.
enum TutorialPlacement {
  /// Always the labelled button: in amber until the player went through the
  /// tutorial once, then a quiet text button.
  always,

  /// Only the amber, labelled button for players who have not seen the
  /// tutorial yet; nothing afterwards.
  untilDone,

  /// Only a small "?" beside the other header icons, once the tutorial was
  /// seen: the start page kept a whole line for it that returning players
  /// no longer needed.
  afterDone,
}

/// Opens the tutorial. Until the player went through it once, the button
/// stands out in amber, since the tutorial never opens by itself.
class TutorialButton extends StatelessWidget {
  const TutorialButton({
    required this.game,
    this.placement = TutorialPlacement.always,
    super.key,
  });

  final TankGame game;
  final TutorialPlacement placement;

  @override
  Widget build(BuildContext context) {
    final label = tr('EINWEISUNG', 'BRIEFING');
    return ValueListenableBuilder<bool>(
      valueListenable: game.tutorialDone,
      builder: (context, done, _) => switch ((placement, done)) {
        (TutorialPlacement.afterDone, false) ||
        (TutorialPlacement.untilDone, true) => const SizedBox.shrink(),
        (TutorialPlacement.afterDone, true) => IconButton(
          tooltip: tr('Einweisung', 'Briefing'),
          onPressed: game.showTutorial,
          icon: const Icon(HorizontSymbols.help),
        ),
        (_, true) => TextButton.icon(
          onPressed: game.showTutorial,
          icon: const Icon(HorizontSymbols.school, size: HzIconSize.row),
          label: Text(label),
        ),
        (_, false) => OutlinedButton.icon(
          onPressed: game.showTutorial,
          icon: const Icon(HorizontSymbols.school, size: HzIconSize.row),
          label: Text(label),
        ),
      },
    );
  }
}
