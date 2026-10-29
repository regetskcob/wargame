import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../l10n/l10n.dart';
import '../ui/theme.dart';
import '../ui/widgets/choice_row.dart';
import '../ui/widgets/pad_pairing.dart';
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
        final two = seats.length >= 2 && splitScreenFits();
        final keyboard = KeyboardSeat.active;
        // Controllers and phones, without the keyboard.
        final others = seats.where((seat) => !seat.keyboard).length;
        if (onTv || others == 0) {
          return const SizedBox.shrink();
        }
        // A sunken box with the one outline, an icon in front and an arrow
        // behind: it reads as a setting of this screen, not as one more
        // mode beside the framed mode cards. The arrow opens the pairing,
        // where a phone comes in as a second seat.
        return Padding(
          padding: const EdgeInsets.only(top: HzSpace.s12),
          child: Material(
            color: GameColors.sunken,
            shape: GameShapes.card(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => PadPairingDialog.show(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  HzSpace.s12,
                  HzSpace.s12,
                  HzSpace.s4,
                  HzSpace.s12,
                ),
                child: Row(
                  children: [
                    Icon(
                      HorizontSymbols.sportsEsports,
                      color: GameColors.textMuted,
                      size: HzIconSize.row,
                    ),
                    const SizedBox(width: HzSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Kennung(tr('CONTROLLER', 'CONTROLLERS')),
                          const SizedBox(height: HzSpace.s4),
                          Text(
                            two
                                ? tr(
                                    'Spieler 1: ${seats[0].label}, Spieler 2: '
                                        '${seats[1].label}. Die Runden laufen '
                                        'auf geteiltem Bildschirm, und das '
                                        'Duell ist offen.',
                                    'Player 1: ${seats[0].label}, player 2: '
                                        '${seats[1].label}. Rounds play on a '
                                        'split screen, and the duel is open.',
                                  )
                                : !splitScreenFits()
                                // A phone has no room for a second half.
                                ? tr(
                                    '${seats[0].label} steuert deinen Panzer.',
                                    '${seats[0].label} steers your tank.',
                                  )
                                : tr(
                                    '${seats[0].label} steuert deinen Panzer. '
                                        'Mit einem zweiten Controller oder '
                                        'Handy spielt ihr zu zweit.',
                                    '${seats[0].label} steers your tank. With '
                                        'a second controller or phone two of '
                                        'you play.',
                                  ),
                            style: GameType.callout.copyWith(
                              color: GameColors.textMuted,
                            ),
                          ),
                          // On a computer the keyboard makes a second seat,
                          // so one controller is enough for two.
                          if (KeyboardSeat.available &&
                              (keyboard || others == 1)) ...[
                            const SizedBox(height: HzSpace.s12),
                            ChoiceRow<bool>(
                              options: [
                                (false, tr('ALLEIN', 'ALONE'), null),
                                (
                                  true,
                                  tr(
                                    'ZU ZWEIT MIT TASTATUR',
                                    'TWO WITH THE KEYBOARD',
                                  ),
                                  null,
                                ),
                              ],
                              selected: keyboard,
                              onSelected: (v) =>
                                  KeyboardSeat.enabled.value = v ?? keyboard,
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: tr('Handy koppeln', 'Pair phone'),
                      onPressed: () => PadPairingDialog.show(context),
                      icon: Icon(
                        HorizontSymbols.chevronRight,
                        color: GameColors.text,
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
