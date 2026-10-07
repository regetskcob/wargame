import 'package:flutter/material.dart';

import '../game/game_mode.dart';
import '../game/space_game.dart';
import '../game_config.dart';
import '../net/room.dart';
import '../theme.dart';
import 'widgets/mute_button.dart';
import 'widgets/pilot_card.dart';
import 'widgets/room_list.dart';

/// Start page of the host: alone, with others or together against waves.
/// Everything else is set in the waiting room that follows.
class LaunchView extends StatelessWidget {
  const LaunchView({required this.game, super.key});

  final SpaceGame game;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'PANZERGEFECHT',
                  maxLines: 1,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
            ),
            const MuteButton(),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Wähle, wie du spielen willst.',
          style: TextStyle(color: BwColors.textDim),
        ),
        const SizedBox(height: 16),
        PilotCard(progress: game.progress),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, box) {
            // Three cards side by side when there is room, else one per row.
            final columns = box.maxWidth >= 640 ? 3 : 1;
            final width = (box.maxWidth - 12 * (columns - 1)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final option in _options)
                  SizedBox(
                    width: width.floorToDouble(),
                    child: _ModeCard(
                      option: option,
                      onTap: () => game.chooseMode(option.mode),
                    ),
                  ),
              ],
            );
          },
        ),
        if (roomLink(game.net.room).isNotEmpty) ...[
          const SizedBox(height: 28),
          RoomList(game: game),
        ],
      ],
    );
  }
}

typedef _Option = ({
  GameMode mode,
  IconData icon,
  String title,
  String kicker,
  String text,
});

const List<_Option> _options = [
  (
    mode: GameMode.solo,
    icon: Icons.person,
    title: 'EINZELSPIELER',
    kicker: 'ALLEIN GEGEN CPU',
    text:
        'Du gegen ${GameConfig.minBots} bis ${GameConfig.maxBots} '
        'CPU-Panzer auf drei Stufen. Der letzte Panzer im Feld gewinnt.',
  ),
  (
    mode: GameMode.multi,
    icon: Icons.groups,
    title: 'MEHRSPIELER',
    kicker: 'GEFECHT MIT ANDEREN',
    text:
        'Lade per Link oder Code ein, alle gegen alle oder Rot gegen Blau. '
        'CPU-Panzer füllen auf Wunsch auf.',
  ),
  (
    mode: GameMode.defense,
    icon: Icons.shield,
    title: 'VERTEIDIGUNG',
    kicker: 'TOWER DEFENSE',
    text:
        'Haltet gemeinsam den Stützpunkt gegen ${GameConfig.defenseWaves} '
        'Wellen. Abschüsse bringen Mittel für Geschütze.',
  ),
];

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.option, required this.onTap});

  final _Option option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = BeveledRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: BwColors.oliveLight, width: 1.5),
    );
    return Material(
      color: const Color(0x44000000),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: const Color(0x22FFB300),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(option.icon, color: BwColors.amber, size: 36),
              const SizedBox(height: 12),
              // Shrinks on narrow cards instead of breaking the word.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  option.title,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: BwColors.sand,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                option.kicker,
                style: const TextStyle(
                  color: BwColors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                option.text,
                style: const TextStyle(color: BwColors.textDim, fontSize: 12),
              ),
              const SizedBox(height: 14),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'WEITER',
                    style: TextStyle(
                      color: BwColors.amber,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: BwColors.amber),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
