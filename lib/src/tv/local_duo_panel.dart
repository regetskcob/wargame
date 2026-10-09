import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../ui/theme.dart';
import '../ui/widgets/panel.dart';
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
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: const Color(0x44000000),
              shape: GameShapes.card(),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('CONTROLLER', 'CONTROLLERS'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    seats.length >= 2
                        ? tr(
                            'Spieler 1: ${seats[0].label}, Spieler 2: '
                                '${seats[1].label}. Die Runden laufen auf '
                                'geteiltem Bildschirm, und das Duell ist '
                                'offen.',
                            'Player 1: ${seats[0].label}, player 2: '
                                '${seats[1].label}. Rounds play on a split '
                                'screen, and the duel is open.',
                          )
                        : tr(
                            '${seats[0].label} steuert deinen Panzer. Mit '
                                'einem zweiten Controller oder Handy spielt '
                                'ihr zu zweit.',
                            '${seats[0].label} steers your tank. With a '
                                'second controller or phone two of you play.',
                          ),
                    style: const TextStyle(color: GameColors.textDim),
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
