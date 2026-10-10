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
        // Leaving records nothing, neither a loss nor the experience: say
        // so, and once the defense is won let the host end it as a win
        // instead, the way out the extension was missing.
        final won = game.defenseWonAlready;
        final host = game.round?.botHost == game.myId;
        final String note;
        if (won && host) {
          note = tr(
            'Der Sieg ist gesichert. Beende die Runde, damit er zählt; '
                'Verlassen wertet sie nicht.',
            'The victory is secured. End the round so it counts; leaving '
                'does not record it.',
          );
        } else if (won) {
          note = tr(
            'Der Sieg zählt, wenn der Host die Runde beendet. Verlassen '
                'wertet sie für dich nicht.',
            'The victory counts once the host ends the round. Leaving does '
                'not record it for you.',
          );
        } else {
          note = tr(
            'Die Runde wird dann nicht gewertet: keine EP, keine '
                'Abzeichen, keine Niederlage.',
            'The round is then not recorded: no XP, no badges, no defeat.',
          );
        }
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
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      note,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: GameColors.textDim,
                      ),
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
                      if (won && host)
                        FilledButton.icon(
                          onPressed: () {
                            game.pointerOnHud = false;
                            game.leaveAsked.value = false;
                            game.withdrawDefense();
                          },
                          icon: const Icon(Icons.flag_outlined),
                          label: Text(tr('SIEG · BEENDEN', 'WIN · END')),
                        ),
                      (won && host ? OutlinedButton.new : FilledButton.new)(
                        style: won && host
                            ? null
                            : FilledButton.styleFrom(
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
