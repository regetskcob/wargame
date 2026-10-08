import 'package:flutter/material.dart';

import '../../game/space_game.dart';
import '../../theme.dart';

/// The player's call sign, read only. It is changed in the account sheet
/// behind the profile button next to it.
class CallSign extends StatelessWidget {
  const CallSign({required this.game, super.key});

  final SpaceGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: game.pilotVersion,
      builder: (context, _, _) => Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: ShapeDecoration(
          color: const Color(0x44000000),
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: BwColors.oliveLight, width: 1.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.badge_outlined, size: 18, color: BwColors.amber),
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
