import 'dart:async';

import 'package:flutter/material.dart';

import '../db/room_slots.dart';
import '../db/server_status.dart';
import '../game/game_config.dart';
import '../game/game_mode.dart';
import '../game/tank_game.dart';
import '../net/room.dart';
import '../tv/seats.dart';
import '../net/pad_link.dart';
import '../tv/local_duo_panel.dart';
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
import 'widgets/rooms_busy_notice.dart';
import 'widgets/server_notice.dart';
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
          // of squeezing the title, and shares it with the briefing.
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: CallSign(game: game)),
                    const SizedBox(width: 8),
                    TutorialButton(game: game),
                  ],
                ),
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
      LayoutBuilder(
        builder: (context, box) => box.maxWidth < 480
            ? const SizedBox(height: 16)
            : Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TutorialButton(game: game),
                ),
              ),
      ),
      PilotCard(progress: game.progress),
      const SizedBox(height: 20),
      // The television walks its menu with the remote, one more stop
      // there costs more than it saves.
      if (!onTv) _QuickStart(game: game),
      const ServerNotice(),
      RoomsBusyNotice(slots: game.slots),
      ListenableBuilder(
        listenable: Listenable.merge([ServerStatus.available, RoomSlots.load]),
        builder: (context, _) => _modes(ServerStatus.available.value),
      ),
      // In the browser and on a tablet: two on this screen, and their duel.
      if (!onTv && padsSupported) ...[
        ListenableBuilder(
          listenable: TvInputSeats.listenable,
          builder: (context, _) => duelSeats().length >= 2
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _DuelCard(game: game),
                )
              : const SizedBox.shrink(),
        ),
        const LocalDuoPanel(),
      ],
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
    ];
  }

  /// Playing with others needs the server; alone the game goes on without.
  Widget _modes(bool online) {
    VoidCallback? start(GameMode mode) =>
        online || mode != GameMode.multi ? () => game.chooseMode(mode) : null;
    return LayoutBuilder(
      builder: (context, box) {
        final cards = <Widget>[
          for (final option in _options)
            _ModeCard(
              icon: option.icon,
              title: option.title,
              kicker: option.mode == GameMode.multi && RoomSlots.allTaken
                  ? tr('ALLE RÄUME BELEGT', 'ALL ROOMS TAKEN')
                  : option.kicker,
              onTap: start(option.mode),
            ),
          if (onTv) _DuelCard(game: game),
        ];
        // Two by two on the television, with the duel last. Elsewhere all
        // four side by side when there is room, two by two on a tablet,
        // else one per row. Cards in a row are equally tall, so it reads
        // calmly.
        final perRow = onTv
            ? 2
            : box.maxWidth >= 900
            ? 4
            : box.maxWidth >= 480
            ? 2
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
    );
  }
}

/// Straight into a solo round with the tank and difficulty used last.
class _QuickStart extends StatelessWidget {
  const _QuickStart({required this.game});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        game.isHost,
        game.pilotVersion,
        game.botLevel,
      ]),
      builder: (context, _) {
        if (!game.isHost.value) {
          return const SizedBox.shrink();
        }
        final tank = GameConfig.typeOf(game.myColorIndex).label;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FilledButton.icon(
            onPressed: game.quickStart,
            icon: const Icon(Icons.play_arrow),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${tr('SOFORT LOS', 'PLAY NOW')}  ·  $tank  ·  '
                '${game.botLevel.value.label}',
                maxLines: 1,
              ),
            ),
          ),
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
  (
    mode: GameMode.flag,
    icon: Icons.outlined_flag,
    title: tr('FAHNENRAUB', 'CAPTURE THE FLAG'),
    kicker: tr('ROT GEGEN BLAU', 'RED AGAINST BLUE'),
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

  /// Null while the mode cannot be played, which greys the card out.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(opacity: onTap == null ? 0.45 : 1, child: _card(context));
  }

  Widget _card(BuildContext context) {
    return Material(
      color: const Color(0x44000000),
      shape: GameShapes.card(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: const Color(0x22FFB300),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Icon(icon, color: GameColors.amber, size: 30),
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
                          color: GameColors.sand,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      onTap == null
                          ? tr('GERADE NICHT VERFÜGBAR', 'NOT AVAILABLE NOW')
                          : kicker,
                      style: const TextStyle(
                        color: GameColors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: GameColors.amber),
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
  const _DuelCard({required this.game});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        TvInput.instance.count,
        PadScreen.instance.phones,
      ]),
      builder: (context, _) => _card(context, duelSeats().length),
    );
  }

  Widget _card(BuildContext context, int count) {
    return _ModeCard(
      icon: Icons.splitscreen,
      title: tr('DUELL', 'DUEL'),
      kicker: count >= 2
          ? tr('ROT GEGEN BLAU · STÜTZPUNKTE', 'RED AGAINST BLUE · BASES')
          : tr('ZWEITER SPIELER FEHLT', 'NEEDS A SECOND PLAYER'),
      onTap: () => count >= 2
          ? game.chooseMode(GameMode.defense, duel: true)
          : unawaited(_explain(context)),
    );
  }

  Future<void> _explain(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: GameColors.surface,
        title: Text(tr('ZWEI SPIELER', 'TWO PLAYERS')),
        content: Text(
          tr(
            'Im Duell verteidigt jeder seinen eigenen Stützpunkt, auf einem '
                'geteilten Bildschirm. Jeder braucht etwas zum Steuern: einen '
                'Controller (in den Einstellungen des Apple TV unter '
                'Fernbedienungen und Geräte > Bluetooth), ein Handy (rechts '
                'über Handy koppeln, zwei Handys scannen denselben Code) oder '
                'die Siri Remote.',
            'In a duel each player defends a base of their own on a split '
                'screen. Each needs something to steer with: a controller (in '
                'the Apple TV settings under Remotes and Devices > Bluetooth), '
                'a phone (with Pair phone on the right, two phones scan the '
                'same code) or the Siri Remote.',
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
