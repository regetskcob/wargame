import 'package:flutter/material.dart';

import '../db/server_status.dart';
import '../game/game_mode.dart';
import '../game/tank_game.dart';
import '../net/room.dart';
import 'theme.dart';
import 'widgets/leaderboard.dart';
import 'widgets/legal.dart';
import 'widgets/account_sheet.dart';
import 'widgets/call_sign.dart';
import 'widgets/mute_button.dart';
import 'widgets/pilot_card.dart';
import 'widgets/tutorial_button.dart';
import 'widgets/room_list.dart';
import 'widgets/server_notice.dart';
import 'widgets/panel.dart';
import '../l10n/l10n.dart';

/// Start page of the host: alone, with others or together against waves.
/// Everything else is set in the waiting room that follows.
class LaunchView extends StatelessWidget {
  const LaunchView({required this.game, super.key});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final title = Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'PANZERGEFECHT',
                  maxLines: 1,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
            );
            // Upright phones: the call sign gets a line of its own instead
            // of squeezing the title.
            if (box.maxWidth < 480) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      title,
                      AccountButton(game: game),
                      const MuteButton(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CallSign(game: game),
                ],
              );
            }
            return Row(
              children: [
                title,
                const SizedBox(width: 12),
                CallSign(game: game),
                AccountButton(game: game),
                const MuteButton(),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TutorialButton(game: game),
        ),
        const SizedBox(height: 16),
        PilotCard(progress: game.progress),
        const SizedBox(height: 20),
        const ServerNotice(),
        ValueListenableBuilder<bool>(
          valueListenable: ServerStatus.available,
          builder: (context, online, _) => _modes(online),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: ServerStatus.available,
          builder: (context, online, _) =>
              online && roomLink(game.net.room).isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: RoomList(game: game),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 28),
        Leaderboard(game: game),
        const SizedBox(height: 16),
        const LegalLinks(),
      ],
    );
  }

  /// Playing with others needs the server; alone the game goes on without.
  Widget _modes(bool online) {
    VoidCallback? start(GameMode mode) =>
        online || mode != GameMode.multi ? () => game.chooseMode(mode) : null;
    return LayoutBuilder(
      builder: (context, box) {
        // Three cards side by side when there is room, else one per row.
        // All three equally tall, so the row reads calmly.
        if (box.maxWidth >= 640) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, option) in _options.indexed) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(
                    child: _ModeCard(option: option, onTap: start(option.mode)),
                  ),
                ],
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, option) in _options.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              _ModeCard(option: option, onTap: start(option.mode)),
            ],
          ],
        );
      },
    );
  }
}

typedef _Option = ({GameMode mode, IconData icon, String title, String kicker});

List<_Option> get _options => [
  (
    mode: GameMode.solo,
    icon: Icons.person,
    title: tr('EINZELSPIELER', 'SINGLE PLAYER'),
    kicker: tr('ALLEIN GEGEN CPU', 'ALONE AGAINST THE CPU'),
  ),
  (
    mode: GameMode.multi,
    icon: Icons.groups,
    title: tr('MEHRSPIELER', 'MULTIPLAYER'),
    kicker: tr('GEFECHT MIT ANDEREN', 'BATTLE WITH OTHERS'),
  ),
  (
    mode: GameMode.defense,
    icon: Icons.shield,
    title: tr('VERTEIDIGUNG', 'DEFENSE'),
    kicker: tr('STÜTZPUNKT HALTEN', 'HOLD THE BASE'),
  ),
];

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.option, required this.onTap});

  final _Option option;

  /// Null while the mode cannot be played, which greys the card out.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: const Color(0x44000000),
        shape: BwShapes.card(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: const Color(0x22FFB300),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(
              children: [
                Icon(option.icon, color: BwColors.amber, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shrinks on narrow cards instead of breaking the word.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          option.title,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: BwColors.sand,
                              ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        onTap == null
                            ? tr('GERADE NICHT VERFÜGBAR', 'NOT AVAILABLE NOW')
                            : option.kicker,
                        style: const TextStyle(
                          color: BwColors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: BwColors.amber),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
