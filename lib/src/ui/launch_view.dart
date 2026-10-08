import 'dart:async';

import 'package:flutter/material.dart';

import '../game/game_mode.dart';
import '../game/tank_game.dart';
import '../net/room.dart';
import '../tv/duel_view.dart';
import '../tv/tv_controllers.dart';
import '../tv/tv_input.dart';
import 'theme.dart';
import 'widgets/leaderboard.dart';
import 'widgets/legal.dart';
import 'widgets/account_sheet.dart';
import 'widgets/call_sign.dart';
import 'widgets/mute_button.dart';
import 'widgets/pilot_card.dart';
import 'widgets/tutorial_button.dart';
import 'widgets/room_list.dart';
import 'widgets/panel.dart';
import '../l10n/l10n.dart';

/// Start page of the host: alone, with others or together against waves.
/// Everything else is set in the waiting room that follows.
class LaunchView extends StatelessWidget {
  const LaunchView({required this.game, super.key});

  final TankGame game;

  /// From this width the leaderboard moves into a column of its own, as on
  /// the television, so the page fits without scrolling.
  static const _twoColumns = 1100.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < _twoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [..._main(context), ..._ranking()],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Each column a group of its own: a remote walks down the left
            // one before it moves on to the right.
            Expanded(
              child: FocusTraversalGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _main(context),
                ),
              ),
            ),
            const SizedBox(width: 28),
            Expanded(
              child: FocusTraversalGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  // Level with the call sign row.
                  children: [const SizedBox(height: 4), ..._ranking(top: 0)],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Leaderboard and the legal links, on the television first the
  /// controllers.
  List<Widget> _ranking({double top = 28}) => [
    SizedBox(height: top),
    if (onTv) ...[TvControllers(game: game), const SizedBox(height: 20)],
    Leaderboard(game: game),
    const SizedBox(height: 16),
    const LegalLinks(),
  ];

  /// Name, rank, the three ways to play and the open rooms.
  List<Widget> _main(BuildContext context) {
    return [
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
      LayoutBuilder(
        builder: (context, box) {
          final cards = <Widget>[
            for (final option in _options)
              _ModeCard(
                icon: option.icon,
                title: option.title,
                kicker: option.kicker,
                onTap: () => game.chooseMode(option.mode),
              ),
            if (onTv) const _DuelCard(),
          ];
          // Two by two on the television, with the duel as the fourth.
          // Elsewhere three side by side when there is room, else one per
          // row. Cards in a row are equally tall, so it reads calmly.
          final perRow = onTv
              ? 2
              : box.maxWidth >= 640
              ? 3
              : 1;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var row = 0; row < cards.length; row += perRow) ...[
                if (row > 0) const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = row; i < row + perRow; i++) ...[
                        if (i > row) const SizedBox(width: 12),
                        Expanded(
                          child: i < cards.length
                              ? cards[i]
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
      if (roomLink(game.net.room).isNotEmpty) ...[
        const SizedBox(height: 28),
        RoomList(game: game),
      ],
    ];
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
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.kicker,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String kicker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
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
              Icon(icon, color: BwColors.amber, size: 30),
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
                        title,
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
                      kicker,
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
    );
  }
}

/// The Apple TV's fourth way to play: two players, two controllers, one
/// screen split in half.
class _DuelCard extends StatelessWidget {
  const _DuelCard();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: TvInput.instance.count,
      builder: (context, count, _) => _ModeCard(
        icon: Icons.splitscreen,
        title: tr('DUELL', 'DUEL'),
        kicker: count >= 2
            ? tr('1 GEGEN 1 VERTEIDIGEN', '1 ON 1 DEFENSE')
            : tr('ZWEITER CONTROLLER NÖTIG', 'NEEDS A SECOND CONTROLLER'),
        onTap: () => count >= 2
            ? unawaited(DuelView.open(context))
            : unawaited(_explain(context)),
      ),
    );
  }

  Future<void> _explain(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: BwColors.surface,
        title: Text(tr('ZWEI CONTROLLER', 'TWO CONTROLLERS')),
        content: Text(
          tr(
            'Im Duell verteidigt jeder seinen eigenen Stützpunkt, auf einem '
                'geteilten Bildschirm. Dafür braucht es zwei Controller: '
                'Verbinde einen Controller in den Einstellungen des Apple TV '
                'unter Fernbedienungen und Geräte > Bluetooth. Die Siri Remote '
                'zählt als einer.',
            'In a duel each player defends a base of their own on a split '
                'screen. That takes two controllers: connect a controller in '
                'the Apple TV settings under Remotes and Devices > Bluetooth. '
                'The Siri Remote counts as one.',
          ),
        ),
        actions: [
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
