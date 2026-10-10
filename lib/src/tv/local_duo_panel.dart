import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../ui/theme.dart';
import '../ui/widgets/pad_pairing.dart';
import 'seats.dart';
import 'tv_input.dart';

/// On the start page in the browser and on a tablet, once a controller or a
/// phone is there: one of them steers the own tank, two of them play two on
/// this screen.
class LocalDuoPanel extends StatelessWidget {
  const LocalDuoPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TvInputSeats.listenable,
      builder: (context, _) {
        final seats = duelSeats();
        if (onTv || seats.isEmpty) {
          return const SizedBox.shrink();
        }
        // A quiet dark box without a frame, an icon in front and an arrow
        // behind: it reads as a setting of this screen, not as one more
        // mode beside the framed mode cards. The arrow opens the pairing,
        // where a phone comes in as a second seat.
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Material(
            color: const Color(0x55000000),
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => PadPairingDialog.show(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.sports_esports,
                      color: GameColors.sand,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('CONTROLLER', 'CONTROLLERS'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: GameColors.textDim,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            seats.length >= 2
                                ? tr(
                                    'Spieler 1: ${seats[0].label}, Spieler 2: '
                                        '${seats[1].label}. Die Runden laufen '
                                        'auf geteiltem Bildschirm, und das '
                                        'Duell ist offen.',
                                    'Player 1: ${seats[0].label}, player 2: '
                                        '${seats[1].label}. Rounds play on a '
                                        'split screen, and the duel is open.',
                                  )
                                : tr(
                                    '${seats[0].label} steuert deinen Panzer. '
                                        'Mit einem zweiten Controller oder '
                                        'Handy spielt ihr zu zweit.',
                                    '${seats[0].label} steers your tank. With '
                                        'a second controller or phone two of '
                                        'you play.',
                                  ),
                            style: const TextStyle(
                              fontSize: 13,
                              color: GameColors.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: tr('Handy koppeln', 'Pair phone'),
                      onPressed: () => PadPairingDialog.show(context),
                      icon: const Icon(
                        Icons.chevron_right,
                        color: GameColors.sand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
