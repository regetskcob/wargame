import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../net/pad_link.dart';
import '../ui/theme.dart';
import '../ui/widgets/panel.dart';
import 'seats.dart';
import 'tv_input.dart';

/// On the start page in the browser and on a tablet, once a controller or a
/// phone is there: playing two on this screen. The first player may keep
/// the keyboard and mouse or the touch screen, the controller or phone is
/// then the second.
class LocalDuoPanel extends StatelessWidget {
  const LocalDuoPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TvInputSeats.listenable,
      builder: (context, _) {
        final input = TvInput.instance;
        final pads = input.pads.length;
        final phones = PadScreen.instance.phones.value.length;
        if (onTv || pads + phones == 0) {
          return const SizedBox.shrink();
        }
        final seats = duelSeats();
        final own = input.ownInput.value;
        final touch =
            Theme.of(context).platform == TargetPlatform.iOS ||
            Theme.of(context).platform == TargetPlatform.android;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: const Color(0x44000000),
              shape: BwShapes.card(),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('ZU ZWEIT', 'TWO PLAYERS'),
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
                            'Ein zweiter Controller oder ein zweites Handy, '
                                'oder du spielst selbst mit '
                                '${touch ? 'Touch' : 'Tastatur und Maus'}, '
                                'dann spielt ihr zu zweit.',
                            'A second controller or phone, or you play with '
                                '${touch ? 'touch' : 'keyboard and mouse'} '
                                'yourself, and two of you play.',
                          ),
                    style: const TextStyle(color: BwColors.textDim),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: own,
                    onChanged: (on) => input.ownInput.value = on,
                    title: Text(
                      touch
                          ? tr(
                              'Spieler 1 spielt mit Touch',
                              'Player 1 plays with touch',
                            )
                          : tr(
                              'Spieler 1 spielt mit Tastatur und Maus',
                              'Player 1 plays with keyboard and mouse',
                            ),
                    ),
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
