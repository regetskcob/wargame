import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../game/components/tank_painter.dart';
import '../game/bot_level.dart';
import '../game/game_mode.dart';
import '../game/tank_game.dart';
import '../game/game_config.dart';
import '../l10n/l10n.dart';
import '../net/room.dart';
import '../net/room_directory.dart';
import '../ui/theme.dart';
import 'wear_crown.dart';
import '../ui/widgets/tank_choice.dart';
import 'account_link.dart';
import 'watch_widgets.dart';

/// The menus on the watch: start page and waiting room in one overlay, as
/// compact lists the Digital Crown scrolls.
class WatchLobby extends StatefulWidget {
  const WatchLobby({required this.game, super.key});

  final TankGame game;

  @override
  State<WatchLobby> createState() => _WatchLobbyState();
}

class _WatchLobbyState extends State<WatchLobby> {
  bool _rooms = false;
  bool _closeArmed = false;

  TankGame get game => widget.game;

  @override
  void initState() {
    super.initState();
    // The watch signs in to no account itself: it plays under the one of
    // the iPhone app (AccountLink), as a guest until the phone lends one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !game.welcomed.value) {
        game.playAsGuest();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        game.welcomed,
        game.choosingMode,
        game.isHost,
        game.pilotVersion,
      ]),
      builder: (context, _) {
        if (!game.welcomed.value) {
          return const WatchPage(children: []);
        }
        if (game.choosingMode.value && game.isHost.value) {
          return _rooms ? _roomList() : _start();
        }
        return _room();
      },
    );
  }

  Widget _start() {
    return WatchPage(
      key: const ValueKey('start'),
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('PANZERGEFECHT', maxLines: 1, style: GameType.title),
        ),
        const SizedBox(height: HzSpace.s8),
        _CallSignButton(game: game),
        ValueListenableBuilder(
          valueListenable: AccountLink.instance.account,
          builder: (context, linked, _) => Padding(
            padding: const EdgeInsets.only(top: HzSpace.s4),
            child: Text(
              linked != null
                  ? tr(
                      'Konto vom iPhone, wird gewertet',
                      'iPhone account, ranked',
                    )
                  // Only the Apple Watch borrows the phone's account.
                  : onWear
                  ? tr('Gast, ohne Wertung', 'Guest, unranked')
                  : tr(
                      'Gast. Melde dich in der iPhone-App an.',
                      'Guest. Sign in in the iPhone app.',
                    ),
              textAlign: TextAlign.center,
              style: GameType.caption,
            ),
          ),
        ),
        const SizedBox(height: HzSpace.s8),
        WatchButton(
          label: tr('EINZELSPIELER', 'SINGLE PLAYER'),
          icon: HorizontSymbols.person,
          primary: true,
          onPressed: () => game.chooseMode(GameMode.solo),
        ),
        WatchButton(
          label: tr('MEHRSPIELER', 'MULTIPLAYER'),
          icon: HorizontSymbols.groups,
          onPressed: () => game.chooseMode(GameMode.multi),
        ),
        WatchButton(
          label: tr('VERTEIDIGUNG', 'DEFENSE'),
          icon: HorizontSymbols.shield,
          onPressed: () => game.chooseMode(GameMode.defense),
        ),
        WatchButton(
          label: tr('FAHNENRAUB', 'CAPTURE THE FLAG'),
          icon: HorizontSymbols.outlinedFlag,
          onPressed: () => game.chooseMode(GameMode.flag),
        ),
        // Without a room channel every mode is played alone against CPU
        // tanks, there are no rooms to join.
        if (!game.net.offline)
          WatchButton(
            label: tr('OFFENE RÄUME', 'OPEN ROOMS'),
            icon: HorizontSymbols.meetingRoom,
            onPressed: () => setState(() => _rooms = true),
          ),
      ],
    );
  }

  Widget _roomList() {
    return WatchPage(
      key: const ValueKey('rooms'),
      children: [
        WatchButton(
          label: tr('ZURÜCK', 'BACK'),
          icon: HorizontSymbols.arrowBack,
          onPressed: () => setState(() => _rooms = false),
        ),
        ValueListenableBuilder<List<RoomListing>>(
          valueListenable: game.directory.rooms,
          builder: (context, rooms, _) {
            if (rooms.isEmpty) {
              return Text(
                tr(
                  'Gerade ist kein öffentlicher Raum offen.',
                  'There is no public room open right now.',
                ),
                style: GameType.callout.copyWith(color: GameColors.textMuted),
              );
            }
            return Column(
              children: [
                for (final room in rooms.take(8))
                  WatchButton(
                    label: '${room.host} · ${room.players}',
                    icon: room.inMatch
                        ? HorizontSymbols.visibility
                        : HorizontSymbols.login,
                    onPressed: () => joinRoom(room.room),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _room() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        game.mode,
        game.roster,
        game.botLevel,
        game.publicRoom,
        game.progress.rank,
      ]),
      builder: (context, _) {
        final host = game.isHost.value;
        final mode = game.mode.value;
        return WatchPage(
          key: const ValueKey('room'),
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                switch (mode) {
                  GameMode.solo => tr('EINZELSPIELER', 'SINGLE PLAYER'),
                  GameMode.multi => tr('MEHRSPIELER', 'MULTIPLAYER'),
                  GameMode.defense => tr('VERTEIDIGUNG', 'DEFENSE'),
                  GameMode.flag => tr('FAHNENRAUB', 'CAPTURE THE FLAG'),
                },
                maxLines: 1,
                style: GameType.title,
              ),
            ),
            const SizedBox(height: HzSpace.s8),
            WatchButton(
              label: host
                  ? tr('GEFECHT STARTEN', 'START BATTLE')
                  : tr('WARTE AUF GASTGEBER', 'WAITING FOR HOST'),
              icon: HorizontSymbols.flag,
              primary: true,
              onPressed: host && game.liveMatch == null
                  ? () {
                      game.setPilot(
                        name: game.myName,
                        colorIndex: game.myColorIndex,
                      );
                      game.startRound();
                    }
                  : null,
            ),
            if (game.liveMatch != null)
              WatchButton(
                label: tr('ZUSEHEN', 'WATCH'),
                icon: HorizontSymbols.visibility,
                onPressed: game.spectateLiveMatch,
              ),
            WatchLabel(tr('FAHRZEUG', 'VEHICLE')),
            _TankPicker(game: game),
            if (host) ...[
              if (mode != GameMode.multi) ...[
                WatchLabel(tr('SCHWIERIGKEIT', 'DIFFICULTY')),
                WatchButton(
                  label: game.botLevel.value.label,
                  icon: HorizontSymbols.tune,
                  onPressed: () => game.chooseLevel(
                    BotLevel.values[(game.botLevel.value.index + 1) %
                        BotLevel.values.length],
                  ),
                ),
              ],
              if (mode == GameMode.multi && !game.net.offline)
                WatchButton(
                  label: game.publicRoom.value
                      ? tr('ÖFFENTLICH', 'PUBLIC')
                      : tr('PRIVAT', 'PRIVATE'),
                  icon: game.publicRoom.value
                      ? HorizontSymbols.public
                      : HorizontSymbols.lock,
                  onPressed: () =>
                      game.publicRoom.value = !game.publicRoom.value,
                ),
              WatchButton(
                label: tr('ZURÜCK', 'BACK'),
                icon: HorizontSymbols.arrowBack,
                onPressed: game.changeMode,
              ),
            ],
            WatchButton(
              label: _closeArmed
                  ? tr('WIRKLICH?', 'REALLY?')
                  : (host
                        ? tr('SCHLIESSEN', 'CLOSE')
                        : tr('VERLASSEN', 'LEAVE')),
              icon: _closeArmed
                  ? HorizontSymbols.warningAmber
                  : HorizontSymbols.close,
              danger: _closeArmed,
              onPressed: () {
                if (_closeArmed) {
                  game.closeRoom();
                } else {
                  setState(() => _closeArmed = true);
                }
              },
            ),
          ],
        );
      },
    );
  }
}

/// The call sign. A tap opens the native watch keyboard.
class _CallSignButton extends StatelessWidget {
  const _CallSignButton({required this.game});

  final TankGame game;

  Future<void> _edit(BuildContext context) async {
    final controller = TextEditingController(text: game.myName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: GameColors.bg,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            HzSpace.s16,
            HzSpace.s48,
            HzSpace.s16,
            HzSpace.s16,
          ),
          child: Column(
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 16,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: tr('RUFNAME', 'CALL SIGN'),
                  counterText: '',
                ),
                onSubmitted: (value) => Navigator.pop(context, value),
              ),
              const SizedBox(height: HzSpace.s8),
              WatchButton(
                label: 'OK',
                primary: true,
                onPressed: () => Navigator.pop(context, controller.text),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) {
      game.setPilot(name: name, colorIndex: game.myColorIndex);
      game.pilotVersion.value++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _edit(context),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(HzSize.touch),
        foregroundColor: GameColors.text,
        side: hairline,
      ),
      icon: Icon(
        HorizontSymbols.badge,
        size: HzIconSize.row,
        color: GameColors.textMuted,
      ),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          game.myName,
          maxLines: 1,
          style: GameType.label.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Vehicle with arrows to the next and previous one the pilot may drive.
class _TankPicker extends StatelessWidget {
  const _TankPicker({required this.game});

  final TankGame game;

  void _step(int by) {
    final types = [
      for (final type in TankType.values)
        if (game.progress.vehicleUnlocked(type)) type,
    ];
    final now = types.indexOf(GameConfig.typeOf(game.myColorIndex));
    final next = types[(now + by) % types.length];
    game.setPilot(
      name: game.myName,
      colorIndex: GameConfig.styleOf(
        next.index,
        game.myColorIndex % GameConfig.tankColors.length,
      ),
    );
    game.pilotVersion.value++;
  }

  /// Narrow, so the vehicle keeps its room on the smallest watch.
  Widget _arrow(IconData icon, VoidCallback onPressed) => IconButton(
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 30, height: 48),
    icon: Icon(icon, color: GameColors.text),
  );

  @override
  Widget build(BuildContext context) {
    final type = GameConfig.typeOf(game.myColorIndex);
    return Row(
      children: [
        _arrow(HorizontSymbols.chevronLeft, () => _step(-1)),
        Expanded(
          child: Column(
            children: [
              SizedBox(
                height: 64,
                child: CustomPaint(
                  size: const Size(80, 64),
                  painter: TankPreviewPainter(
                    type,
                    game.lobbyColorOf(game.myId, game.myColorIndex),
                  ),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  type.label,
                  maxLines: 1,
                  style: GameType.label.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        _arrow(HorizontSymbols.chevronRight, () => _step(1)),
      ],
    );
  }
}
