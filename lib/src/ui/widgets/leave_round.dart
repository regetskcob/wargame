import 'package:flutter/material.dart';

import '../../game/tank_game.dart';
import '../../l10n/l10n.dart';
import '../../tv/tv_input.dart';
import '../theme.dart';
import 'panel.dart';

/// A small, dim exit in the corner of a running round. It only asks: one
/// stray tap must not end a round.
class LeaveRoundButton extends StatelessWidget {
  const LeaveRoundButton({required this.game, super.key});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    // The remote's Menu button steps back on the Apple TV, and a button the
    // focus could reach would steal the arrows from the tank.
    if (onTv) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: game.touchMode.value
          ? tr('Runde verlassen', 'Leave round')
          : tr('Runde verlassen (Esc)', 'Leave round (Esc)'),
      color: GameColors.textDim.withValues(alpha: 0.7),
      onPressed: () => game.leaveAsked.value = true,
      icon: const Icon(Icons.logout_outlined),
    );
  }
}

/// The question after Escape or the exit button, in the middle of the
/// field. The round runs on behind it, it cannot be paused for the others.
class LeaveRoundPrompt extends StatelessWidget {
  const LeaveRoundPrompt({required this.game, super.key});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: game.leaveAsked,
      builder: (context, asked, _) {
        if (!asked) {
          return const SizedBox.shrink();
        }
        final keys = !game.touchMode.value;
        return Center(
          child: MouseRegion(
            onEnter: (_) => game.pointerOnHud = true,
            onExit: (_) => game.pointerOnHud = false,
            child: Panel(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('Runde verlassen?', 'Leave the round?'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () => game.leaveAsked.value = false,
                        child: Text(
                          keys
                              ? tr('WEITERSPIELEN (ESC)', 'KEEP PLAYING (ESC)')
                              : tr('WEITERSPIELEN', 'KEEP PLAYING'),
                        ),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: GameColors.danger,
                        ),
                        onPressed: () {
                          game.pointerOnHud = false;
                          game.leaveRound();
                        },
                        child: Text(
                          keys
                              ? tr('VERLASSEN (ENTER)', 'LEAVE (ENTER)')
                              : tr('VERLASSEN', 'LEAVE'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
