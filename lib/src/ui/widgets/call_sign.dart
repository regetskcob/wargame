import 'package:flutter/material.dart';

import '../../game/tank_game.dart';
import '../theme.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.badge_outlined, size: 18, color: GameColors.amber),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                game.myName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
