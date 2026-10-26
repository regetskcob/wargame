import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

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
