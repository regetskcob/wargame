import 'package:flutter/material.dart';

import '../../db/server_status.dart';
import '../../l10n/l10n.dart';
import '../theme.dart';
import 'panel.dart';

/// Says so while the server does not answer, and nothing otherwise.
class ServerNotice extends StatelessWidget {
  const ServerNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ServerStatus.available,
      builder: (context, available, _) {
        if (available) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: const Color(0x66000000),
              shape: GameShapes.card(),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_outlined, color: GameColors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr(
                        'Das Online-Spiel ist gerade nicht verfügbar. '
                            'Einzelspieler und Verteidigung allein gehen '
                            'weiter, Ränge und Bestenliste warten, bis der '
                            'Server wieder da ist.',
                        'Online play is not available right now. Single '
                            'player and defense on your own go on; ranks '
                            'and the leaderboard wait until the server is '
                            'back.',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
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
