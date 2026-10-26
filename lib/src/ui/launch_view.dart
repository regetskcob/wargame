import 'dart:async';

import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../db/room_slots.dart';
import '../db/server_status.dart';
import '../app/env.dart';
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
import 'widgets/tablet_scale.dart';
import 'account_page.dart';
import 'widgets/call_sign.dart';
import 'widgets/mute_button.dart';
import 'widgets/panel.dart';
import 'widgets/pilot_card.dart';
import 'widgets/tutorial_button.dart';
import 'widgets/room_list.dart';
import 'widgets/rooms_busy_notice.dart';
import 'widgets/server_notice.dart';
import '../l10n/l10n.dart';

/// Start page of the host: alone, with others or together against waves.
/// Everything else is set in the waiting room that follows.
class LaunchView extends StatelessWidget {
  const LaunchView({required this.game, super.key});

  final TankGame game;

  /// From this width the leaderboard moves into a column of its own, as on
  /// the television, so the page fits without scrolling. A tablet held
  /// sideways reaches it, the browser's menu of 1040 at most stays one
  /// column.
  static const _twoColumns = 1000.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < _twoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._main(context),
              if (!onTv) _rooms(top: 28),
              ..._ranking(),
            ],
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
            const SizedBox(width: HzSpace.s32),
            Expanded(
              child: FocusTraversalGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  // Level with the call sign row. Outside the television
                  // the open rooms lead this column: the left one holds the
                  // ways to play, the right one the others.
                  children: [
                    const SizedBox(height: 4),
                    if (onTv)
                      ..._ranking(top: 0)
                    else ...[
                      _rooms(top: 0),
                      ..._ranking(),
                    ],
                  ],
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
    if (onTv) ...[
      TvControllers(game: game),
      const SizedBox(height: HzSpace.s24),
    ],
    // Tablets have the height for twice the pilots; five left the lower
    // half of the page empty.
    Builder(
      builder: (context) => Leaderboard(
        game: game,
        rows: MediaQuery.sizeOf(context).shortestSide >= tabletShortSide
            ? 10
            : 5,
      ),
    ),
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
                child: Row(
                  children: [
                    TutorialButton(game: game),
                    // From tablets up the last round sits quietly at the
                    // end of the briefing's line. Phones keep the space for
                    // the ways to play, and the television walks its menu
                    // with the remote, where one more stop costs more than
                    // it saves.
                    if (box.maxWidth >= 600 && !onTv)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _LastPlayed(game: game),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      // A guest has no rank to show yet, so the way to one takes its place:
      // the profile button alone went unnoticed.
      ValueListenableBuilder(
        valueListenable: game.accounts.user,
        builder: (context, _, _) => Env.accounts && game.accounts.isGuest
            ? _GuestCard(game: game)
            : PilotCard(progress: game.progress, owned: game.shop?.owned),
      ),
      const SizedBox(height: HzSpace.s24),
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
          builder: (context, _) => duelSeats().length >= 2 && splitScreenFits()
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _DuelCard(game: game),
                )
              : const SizedBox.shrink(),
        ),
        const LocalDuoPanel(),
      ],
      if (onTv) _rooms(top: 28),
    ];
  }

  /// The open rooms, while there is a server to find them on.
  Widget _rooms({required double top}) => ValueListenableBuilder<bool>(
    valueListenable: ServerStatus.available,
    builder: (context, online, _) =>
        online && roomLink(game.net.room).isNotEmpty
        ? Padding(
            padding: EdgeInsets.only(top: top),
            child: RoomList(game: game),
          )
        : const SizedBox.shrink(),
  );

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
              if (row > 0) const SizedBox(height: HzSpace.s12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = row; i < row + perRow; i++) ...[
                      if (i > row) const SizedBox(width: HzSpace.s12),
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
class _LastPlayed extends StatelessWidget {
  const _LastPlayed({required this.game});

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
        return TextButton.icon(
          onPressed: game.quickStart,
          icon: const Icon(HorizontSymbols.replay, size: HzIconSize.row),
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${tr('ZULETZT GESPIELT', 'LAST PLAYED')}$horizontMetaSeparator'
              '$tank$horizontMetaSeparator${game.botLevel.value.label}',
              maxLines: 1,
            ),
          ),
        );
      },
    );
  }
}

/// Invites a guest to sign in or create an account, with what it brings.
/// A sunken box with the hairline, quieter than the mode cards; the arrow
/// opens the account.
class _GuestCard extends StatelessWidget {
  const _GuestCard({required this.game});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GameColors.sunken,
      shape: GameShapes.chip(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => AccountPage.open(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            HzSpace.s12,
            HzSpace.s12,
            HzSpace.s4,
            HzSpace.s12,
          ),
          child: Row(
            children: [
              const Icon(
                HorizontSymbols.login,
                color: GameColors.text,
                size: HzIconSize.bar,
              ),
              const SizedBox(width: HzSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(
                        'ALS GAST · ANMELDEN ODER KONTO ANLEGEN',
                        'GUEST · SIGN IN OR CREATE AN ACCOUNT',
                      ),
                      style: GameType.kennung,
                    ),
                    const SizedBox(height: HzSpace.s4),
                    Text(
                      tr(
                        'Mit Konto sammelst du EP, Rang und Abzeichen, '
                            'schaltest Fahrzeuge frei und spielst auf jedem '
                            'Gerät weiter.',
                        'With an account you collect XP, rank and badges, '
                            'unlock vehicles and keep playing on any device.',
                      ),
                      style: GameType.callout.copyWith(
                        color: GameColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Only a sign: the whole card is the button. A button of its
              // own here was a second focus stop on the television and a
              // second button for the screen reader.
              const SizedBox.square(
                dimension: HzSpace.s48,
                child: Icon(
                  HorizontSymbols.chevronRight,
                  color: GameColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _Option = ({GameMode mode, IconData icon, String title, String kicker});

List<_Option> get _options => [
  (
    mode: GameMode.solo,
    icon: HorizontSymbols.person,
    title: tr('EINZELSPIELER', 'SINGLE PLAYER'),
    kicker: tr('ALLEIN GEGEN CPU', 'ALONE AGAINST THE CPU'),
  ),
  (
    mode: GameMode.multi,
    icon: HorizontSymbols.groups,
    title: tr('MEHRSPIELER', 'MULTIPLAYER'),
    kicker: tr('GEFECHT MIT ANDEREN', 'BATTLE WITH OTHERS'),
  ),
  (
    mode: GameMode.defense,
    icon: HorizontSymbols.shield,
    title: tr('VERTEIDIGUNG', 'DEFENSE'),
    kicker: tr('STÜTZPUNKT HALTEN', 'HOLD THE BASE'),
  ),
  (
    mode: GameMode.flag,
    icon: HorizontSymbols.flag,
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
    // A free-standing card: surface, the one outline, radius 10. The way on
    // is the chevron in the accent; hover tints the card like a selection.
    return Material(
      color: GameColors.surface,
      shape: GameShapes.card(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: GameColors.accentTint,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            HzSpace.s16,
            HzSpace.s16,
            HzSpace.s8,
            HzSpace.s16,
          ),
          child: Row(
            children: [
              Icon(icon, color: GameColors.text, size: 28),
              const SizedBox(width: HzSpace.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Shrinks on narrow cards instead of breaking the word.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(title, maxLines: 1, style: GameType.title),
                    ),
                    const SizedBox(height: HzSpace.s4),
                    Text(
                      onTap == null
                          ? tr('GERADE NICHT VERFÜGBAR', 'NOT AVAILABLE NOW')
                          : kicker,
                      style: GameType.kennung,
                    ),
                  ],
                ),
              ),
              const Icon(
                HorizontSymbols.chevronRight,
                color: GameColors.accentText,
              ),
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
      icon: HorizontSymbols.splitscreen,
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
        title: Text(tr('ZWEI SPIELER', 'TWO PLAYERS')),
        content: Text(
          onAppleTv
              ? tr(
                  'Im Duell verteidigt jeder seinen eigenen Stützpunkt, auf '
                      'einem geteilten Bildschirm. Jeder braucht etwas zum '
                      'Steuern: einen Controller (in den Einstellungen des '
                      'Apple TV unter Fernbedienungen und Geräte > Bluetooth), '
                      'ein Handy (rechts über Handy koppeln, zwei Handys '
                      'scannen denselben Code) oder die Siri Remote.',
                  'In a duel each player defends a base of their own on a '
                      'split screen. Each needs something to steer with: a '
                      'controller (in the Apple TV settings under Remotes and '
                      'Devices > Bluetooth), a phone (with Pair phone on the '
                      'right, two phones scan the same code) or the Siri '
                      'Remote.',
                )
              : tr(
                  'Im Duell verteidigt jeder seinen eigenen Stützpunkt, auf '
                      'einem geteilten Bildschirm. Jeder braucht etwas zum '
                      'Steuern: einen Controller (in den Einstellungen des '
                      'Fernsehers per Bluetooth gekoppelt), ein Handy (rechts '
                      'über Handy koppeln, zwei Handys scannen denselben Code) '
                      'oder die Fernbedienung.',
                  'In a duel each player defends a base of their own on a '
                      'split screen. Each needs something to steer with: a '
                      'controller (paired over Bluetooth in the settings of '
                      'the TV), a phone (with Pair phone on the right, two '
                      'phones scan the same code) or the remote.',
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
