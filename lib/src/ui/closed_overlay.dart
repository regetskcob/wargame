import 'package:flutter/material.dart';

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
      color: const Color(0xAA000000),
      child: SafeArea(
        child: Center(
          child: FitOrScroll(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Panel(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('WARTERAUM GESCHLOSSEN', 'WAITING ROOM CLOSED'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<String?>(
                      valueListenable: game.closedReason,
                      builder: (context, reason, _) => Text(
                        reason ?? '',
                        style: const TextStyle(color: GameColors.textDim),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: game.backToStart,
                      icon: const Icon(Icons.home),
                      label: Text(tr('ZUR STARTSEITE', 'TO THE START PAGE')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
