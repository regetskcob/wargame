import 'package:flutter/material.dart';

import '../../game_config.dart';
import '../../net/payloads/lobby_presence.dart';
import '../../theme.dart';
import '../../l10n/l10n.dart';

class PlayerList extends StatelessWidget {
  const PlayerList({
    required this.members,
    required this.myId,
    required this.colorOf,
    super.key,
  });

  final List<LobbyPresence> members;
  final String myId;

  /// Colour the member's tank will have, camouflage or a player colour.
  final Color Function(LobbyPresence member) colorOf;

  @override
  Widget build(BuildContext context) {
    final sorted = List.of(members)..sort((a, b) => a.name.compareTo(b.name));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tr('BESATZUNGEN IM LAGER', 'CREWS IN CAMP'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final member in sorted)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield, size: 16, color: colorOf(member)),
                const SizedBox(width: 8),
                Text(
                  member.id == myId
                      ? '${member.name} (${tr('du', 'you')})'
                      : member.name,
                ),
                if (member.host) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.star, size: 13, color: BwColors.amber),
                ],
                if (member.team > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    GameConfig.teamNames[member.team],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: GameConfig.teamColors[member.team],
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  member.inMatch
                      ? tr('im Einsatz', 'in battle')
                      : tr('im Lager', 'in camp'),
                  style: const TextStyle(color: BwColors.textDim, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
