import 'package:flutter/material.dart';

import '../game/space_game.dart';
import '../theme.dart';
import 'widgets/panel.dart';

/// The waiting room is gone: say why and lead back to the start page.
class ClosedOverlay extends StatelessWidget {
  const ClosedOverlay({required this.game, super.key});

  final SpaceGame game;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xAA000000),
      child: Center(
        child: Padding(
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
                    'WARTERAUM GESCHLOSSEN',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<String?>(
                    valueListenable: game.closedReason,
                    builder: (context, reason, _) => Text(
                      reason ?? '',
                      style: const TextStyle(color: BwColors.textDim),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: game.backToStart,
                    icon: const Icon(Icons.home),
                    label: const Text('ZUR STARTSEITE'),
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
