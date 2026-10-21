import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../../game/tank_game.dart';
import '../theme.dart';
import 'panel.dart';

/// The player's call sign, read only. It is changed in the account sheet
/// behind the profile button next to it.
class CallSign extends StatelessWidget {
  const CallSign({required this.game, super.key});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: game.pilotVersion,
      builder: (context, _, _) => Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(
          horizontal: HzSpace.s12,
          vertical: HzSpace.s8,
        ),
        decoration: ShapeDecoration(shape: GameShapes.chip()),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.badge_outlined,
              size: HzIconSize.row,
              color: GameColors.textMuted,
            ),
            const SizedBox(width: HzSpace.s8),
            Flexible(
              child: Text(
                game.myName,
                overflow: TextOverflow.ellipsis,
                // The call sign is an ID: mono, like every name the game
                // hands out.
                style: GameType.data.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
