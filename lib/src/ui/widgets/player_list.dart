import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../../game/game_config.dart';
import '../../net/payloads/lobby_presence.dart';
import '../theme.dart';
import '../../l10n/l10n.dart';

class PlayerList extends StatelessWidget {
  const PlayerList({
    required this.members,
    required this.myId,
    required this.colorOf,
    this.hostId,
    super.key,
  });

  final List<LobbyPresence> members;
  final String myId;

  /// Colour the member's tank will have, camouflage or a player colour.
  final Color Function(LobbyPresence member) colorOf;

  /// Who hosts the room by the server's ranking, which gets the star. A
  /// presence can claim to host and to own the room: a poser showed a star
  /// of its own while the owner kept the role. Null while the ranking is
  /// unknown, the presences' claims count then.
  final String? hostId;

  @override
  Widget build(BuildContext context) {
    final sorted = List.of(members)..sort((a, b) => a.name.compareTo(b.name));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Kennung(
          tr('Besatzungen im Raum', 'Crews in the room'),
          count: members.length,
        ),
        const SizedBox(height: HzSpace.s8),
        for (final member in sorted)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: HzSpace.s4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  HorizontSymbols.shield,
                  size: HzIconSize.inline,
                  color: colorOf(member),
                ),
                const SizedBox(width: HzSpace.s8),
                Text(
                  member.id == myId
                      ? '${member.name} (${tr('du', 'you')})'
                      : member.name,
                ),
                if (hostId == null ? member.host : member.id == hostId) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    HorizontSymbols.star,
                    size: HzIconSize.badge,
                    color: GameColors.accentText,
                  ),
                ],
                if (member.team > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    GameConfig.teamNames[member.team],
                    style: GameType.kennung.copyWith(
                      color: GameConfig.teamColors[member.team],
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  member.inMatch
                      ? tr('im Einsatz', 'in battle')
                      : tr('wartet', 'waiting'),
                  style: GameType.data.copyWith(
                    color: GameColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
