import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../../db/server_status.dart';
import '../../l10n/l10n.dart';
import 'notice.dart';

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
          padding: const EdgeInsets.only(bottom: HzSpace.s16),
          child: Notice(
            HorizontStatus.warning,
            icon: Icons.cloud_off_outlined,
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
            ),
          ),
        );
      },
    );
  }
}
