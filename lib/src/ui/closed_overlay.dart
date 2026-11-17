import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../db/room_slots.dart';
import '../game/tank_game.dart';
import 'theme.dart';
import 'widgets/fit_or_scroll.dart';
import 'widgets/panel.dart';
import '../l10n/l10n.dart';

/// The waiting room is gone: say why and lead back to the start page.
class ClosedOverlay extends StatelessWidget {
  const ClosedOverlay({required this.game, super.key});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: GameColors.bg.withValues(alpha: 0.7),
      // No reason while the host's own close moves on to the start page.
      child: ValueListenableBuilder<String?>(
        valueListenable: game.closedReason,
        builder: (context, reason, _) =>
            reason == null ? const SizedBox.expand() : _panel(context, reason),
      ),
    );
  }

  Widget _panel(BuildContext context, String reason) {
    return SafeArea(
      child: Center(
        child: FitOrScroll(
          padding: const EdgeInsets.all(HzSpace.s16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Panel(
              padding: const EdgeInsets.all(HzSpace.s24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('WARTERAUM GESCHLOSSEN', 'WAITING ROOM CLOSED'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: HzSpace.s12),
                  Text(
                    reason,
                    style: GameType.body.copyWith(color: GameColors.textMuted),
                  ),
                  ValueListenableBuilder<QueueSpot?>(
                    valueListenable: game.queueSpot,
                    builder: (context, spot, _) => spot == null
                        ? const SizedBox.shrink()
                        : _QueueLine(spot: spot),
                  ),
                  const SizedBox(height: HzSpace.s24),
                  FilledButton.icon(
                    onPressed: game.backToStart,
                    icon: const Icon(HorizontSymbols.home),
                    label: Text(tr('ZUR STARTSEITE', 'TO THE START PAGE')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the pilot stands in line and roughly how long it takes. Keeps its
/// height while the numbers change, so nothing below it jumps.
class _QueueLine extends StatelessWidget {
  const _QueueLine({required this.spot});

  final QueueSpot spot;

  @override
  Widget build(BuildContext context) {
    final minutes = (spot.wait.inSeconds / 60).ceil();
    final text = switch (spot.place) {
      0 => tr('Platz wird ermittelt …', 'Finding your place …'),
      1 => tr('Du bist als Nächstes dran.', 'You are next.'),
      final place => tr(
        'Platz $place in der Warteschlange · etwa $minutes Min.',
        'Place $place in the queue · about $minutes min',
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: HzSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text, style: GameType.body, semanticsLabel: text),
          const SizedBox(height: HzSpace.s8),
          const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
