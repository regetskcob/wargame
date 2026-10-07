import 'dart:async';

import 'package:flutter/material.dart';

import '../env.dart';
import '../game_config.dart';
import '../game/bot_level.dart';
import '../game/game_mode.dart';
import '../game/map_theme.dart';
import '../game/weather.dart';
import '../game/space_game.dart';
import '../net/payloads/lobby_presence.dart';
import '../net/room.dart';
import '../game/components/tank_painter.dart';
import '../theme.dart';
import 'launch_view.dart';
import 'widgets/mute_button.dart';
import 'widgets/choice_row.dart';
import 'widgets/leaderboard.dart';
import 'widgets/account_panel.dart';
import 'widgets/panel.dart';
import 'widgets/pilot_card.dart';
import 'widgets/room_invite.dart';
import 'widgets/room_list.dart';
import 'widgets/player_list.dart';
import 'widgets/tank_choice.dart';

class LobbyOverlay extends StatefulWidget {
  const LobbyOverlay({required this.game, super.key});

  final SpaceGame game;

  @override
  State<LobbyOverlay> createState() => _LobbyOverlayState();
}

class _LobbyOverlayState extends State<LobbyOverlay> {
  late final TextEditingController _nameController;
  late int _colorIndex;
  late int _teamPick = widget.game.teamPick;
  bool _closeArmed = false;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.game.myName);
    _colorIndex = widget.game.myColorIndex;
    widget.game.pilotVersion.addListener(_reloadPilot);
  }

  /// Another account was signed in: show its name and look.
  void _reloadPilot() {
    setState(() {
      _nameController.text = widget.game.myName;
      _colorIndex = widget.game.myColorIndex;
    });
  }

  @override
  void dispose() {
    widget.game.pilotVersion.removeListener(_reloadPilot);
    _closeTimer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  void _pick({int? type, int? color}) {
    if (color != null && !widget.game.progress.unlocked(color)) {
      return;
    }
    setState(() {
      _colorIndex = GameConfig.styleOf(
        type ?? GameConfig.typeOf(_colorIndex).index,
        color ?? _colorIndex % GameConfig.shipColors.length,
      );
    });
    _apply();
  }

  void _apply() {
    widget.game.setPilot(name: _nameController.text, colorIndex: _colorIndex);
  }

  Widget _pilotColumn(BuildContext context) {
    final game = widget.game;
    return Column(
      mainAxisSize: MainAxisSize.min,
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
        ValueListenableBuilder<GameMode>(
          valueListenable: game.mode,
          builder: (context, mode, _) => Text(
            mode == GameMode.defense
                ? 'Verteidigung: Haltet den Stützpunkt gegen alle Wellen.'
                : 'Gefechtsübung: Der letzte Panzer im Feld gewinnt.',
            style: const TextStyle(color: BwColors.textDim),
          ),
        ),
        const SizedBox(height: 16),
        PilotCard(progress: game.progress),
        if (Env.accounts) ...[
          const SizedBox(height: 8),
          AccountPanel(accounts: game.accounts),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          maxLength: 16,
          decoration: const InputDecoration(labelText: 'RUFNAME'),
          onChanged: (_) => _apply(),
        ),
        const SizedBox(height: 8),
        Text('FAHRZEUG', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: Listenable.merge([game.roster, game.mode]),
          builder: (context, _) => LayoutBuilder(
            builder: (context, box) {
              // Two or more cards per row that share the width evenly, all
              // vehicles in one row when there is room.
              final columns = (((box.maxWidth + 8) / 104).floor()).clamp(
                2,
                TankType.values.length,
              );
              final width = (box.maxWidth - 8 * (columns - 1)) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in TankType.values)
                    TankChoice(
                      type: type,
                      width: width.floorToDouble(),
                      color: game.lobbyColorOf(game.myId, _colorIndex),
                      selected: type == GameConfig.typeOf(_colorIndex),
                      onTap: () => _pick(type: type.index),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        StatBars(type: GameConfig.typeOf(_colorIndex)),
        const SizedBox(height: 16),
        ValueListenableBuilder<GameMode>(
          valueListenable: game.mode,
          builder: (context, mode, _) => mode.withOthers
              ? const Text(
                  'Mit anderen fährt jeder Panzer in einer eigenen, '
                  'gut sichtbaren Farbe statt in Tarnung.',
                  style: TextStyle(color: BwColors.textDim, fontSize: 12),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TARNUNG',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder(
                      valueListenable: game.progress.rank,
                      builder: (context, rank, _) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < GameConfig.shipColors.length; i++)
                            Tooltip(
                              message: game.progress.unlocked(i)
                                  ? GameConfig.colorNames[i]
                                  : '${GameConfig.colorNames[i]}: ab Stufe '
                                        '${GameConfig.colorLevels[i]}',
                              child: ColorSwatchButton(
                                color: GameConfig.shipColors[i],
                                selected:
                                    i ==
                                    _colorIndex % GameConfig.shipColors.length,
                                locked: !game.progress.unlocked(i),
                                onTap: () => _pick(color: i),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        if (game.isHost.value) ...[
          ValueListenableBuilder<GameMode>(
            valueListenable: game.mode,
            builder: (context, mode, _) => mode == GameMode.defense
                ? const SizedBox()
                : _teamChoice(context),
          ),
          const SizedBox(height: 16),
          Text('GELÄNDE', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ValueListenableBuilder<int?>(
            valueListenable: game.mapChoice,
            builder: (context, choice, _) => ChoiceRow<int>(
              allowNone: true,
              options: [
                for (var i = 0; i < MapTheme.all.length; i++)
                  (i, MapTheme.all[i].name.toUpperCase(), null),
              ],
              selected: choice,
              onSelected: (v) => game.mapChoice.value = v,
            ),
          ),
          const SizedBox(height: 16),
          Text('WETTER', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ValueListenableBuilder<Sky?>(
            valueListenable: game.skyChoice,
            builder: (context, choice, _) => ChoiceRow<Sky>(
              allowNone: true,
              options: const [
                (Sky.clear, 'KLAR', null),
                (Sky.precipitation, 'NIEDERSCHLAG', null),
                (Sky.fog, 'NEBEL', null),
              ],
              selected: choice,
              onSelected: (v) => game.skyChoice.value = v,
            ),
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<bool?>(
            valueListenable: game.nightChoice,
            builder: (context, choice, _) => ChoiceRow<bool>(
              allowNone: true,
              options: const [(false, 'TAG', null), (true, 'NACHT', null)],
              selected: choice,
              onSelected: (v) => game.nightChoice.value = v,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ohne Auswahl werden Gelände, Wetter und Tageszeit zufällig '
            'bestimmt. Nachts, im Nebel und im Sandsturm siehst du nur, was '
            'nah ist.',
            style: TextStyle(color: BwColors.textDim, fontSize: 12),
          ),
        ] else ...[
          const SizedBox(height: 16),
          const Text(
            'Modus und Gelände legt der Gastgeber fest. '
            'Du suchst dir hier nur Namen und Fahrzeug aus.',
            style: TextStyle(color: BwColors.textDim, fontSize: 12),
          ),
        ],
        const SizedBox(height: 24),
        ValueListenableBuilder<List<LobbyPresence>>(
          valueListenable: game.roster,
          builder: (context, roster, _) {
            final live = game.liveMatch;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: live == null && game.canStart
                      ? () {
                          _apply();
                          game.startRound();
                        }
                      : null,
                  icon: const Icon(Icons.flag),
                  label: Text(
                    game.canStart ? 'ÜBUNG STARTEN' : 'WARTE AUF GASTGEBER',
                  ),
                ),
                if (live != null)
                  OutlinedButton.icon(
                    onPressed: game.spectateLiveMatch,
                    icon: const Icon(Icons.visibility),
                    label: const Text('LAUFENDE ÜBUNG BEOBACHTEN'),
                  ),
                ValueListenableBuilder(
                  valueListenable: game.lastReplay,
                  builder: (context, replay, _) => replay == null
                      ? const SizedBox.shrink()
                      : OutlinedButton.icon(
                          onPressed: game.watchReplay,
                          icon: const Icon(Icons.movie_outlined),
                          label: const Text('LETZTE RUNDE ANSEHEN'),
                        ),
                ),
                OutlinedButton.icon(
                  onPressed: _confirmClose,
                  style: _closeArmed
                      ? OutlinedButton.styleFrom(
                          foregroundColor: BwColors.danger,
                          side: const BorderSide(color: BwColors.danger),
                        )
                      : null,
                  icon: Icon(_closeArmed ? Icons.warning_amber : Icons.close),
                  label: Text(switch ((_closeArmed, game.isHost.value)) {
                    (true, true) => 'WIRKLICH FÜR ALLE SCHLIESSEN?',
                    (true, false) => 'WIRKLICH VERLASSEN?',
                    (false, true) => 'WARTERAUM SCHLIESSEN',
                    (false, false) => 'WARTERAUM VERLASSEN',
                  }),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<bool>(
          valueListenable: game.touchMode,
          builder: (context, touch, _) => Text(
            touch
                ? 'Linker Stick fährt: nach oben vorwärts, zur Seite lenken. '
                      'Rechter Stick richtet den Turm aus, unabhängig von der '
                      'Wanne, und feuert, sobald du über den Ring schiebst. '
                      'Die Sticks erscheinen dort, wo dein Daumen aufsetzt. '
                      'Munition ist knapp: blaue Gems füllen sie auf, rote '
                      'und violette bringen Granatwerfer oder Drohne, die du '
                      'mit dem runden Knopf über dem rechten Stick auslöst.'
                : 'Fahren mit WASD oder Pfeiltasten, der Turm zielt auf die '
                      'Maus (oder Q und E), Feuer mit Leertaste oder Linksklick. '
                      'Munition ist knapp: blaue Gems füllen sie auf, rote '
                      'und violette bringen Granatwerfer oder Drohne, die du '
                      'mit F auslöst. Auf Touchgeräten steuerst du mit zwei '
                      'Sticks am Bildschirm.',
            style: const TextStyle(color: BwColors.textDim, fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// Free for all or red against blue, for the host.
  Widget _teamChoice(BuildContext context) {
    final game = widget.game;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('MODUS', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ValueListenableBuilder<bool>(
          valueListenable: game.teamMode,
          builder: (context, teams, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChoiceRow<bool>(
                options: const [
                  (false, 'ALLE GEGEN ALLE', null),
                  (true, 'TEAMS', null),
                ],
                selected: teams,
                onSelected: (v) => game.teamMode.value = v ?? false,
              ),
              if (teams) ...[
                const SizedBox(height: 10),
                ChoiceRow<int>(
                  options: [
                    (0, 'AUTO', null),
                    (1, 'ROT', GameConfig.teamColors[1]),
                    (2, 'BLAU', GameConfig.teamColors[2]),
                  ],
                  selected: _teamPick,
                  onSelected: (v) {
                    setState(() => _teamPick = v ?? 0);
                    game.setTeamPick(_teamPick);
                  },
                ),
                const SizedBox(height: 6),
                const Text(
                  'AUTO füllt das kleinere Team. Eigene Teammitglieder '
                  'triffst du nicht.',
                  style: TextStyle(color: BwColors.textDim, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// The way to play the host took on the start page, and its settings.
  Widget _modeChoice(BuildContext context) {
    final game = widget.game;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SPIELART', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ValueListenableBuilder<GameMode>(
          valueListenable: game.mode,
          builder: (context, mode, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceRow<GameMode>(
                    options: [
                      (
                        mode,
                        switch (mode) {
                          GameMode.solo => 'EINZELSPIELER',
                          GameMode.multi => 'MEHRSPIELER',
                          GameMode.defense => 'VERTEIDIGUNG',
                        },
                        null,
                      ),
                    ],
                    selected: mode,
                    onSelected: (_) => game.changeMode(),
                  ),
                  TextButton.icon(
                    onPressed: game.changeMode,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('ÄNDERN'),
                  ),
                ],
              ),
              if (mode == GameMode.multi &&
                  roomLink(game.net.room).isNotEmpty) ...[
                const SizedBox(height: 10),
                ValueListenableBuilder<bool>(
                  valueListenable: game.publicRoom,
                  builder: (context, public, _) => ChoiceRow<bool>(
                    options: const [
                      (false, 'PRIVAT', null),
                      (true, 'ÖFFENTLICH', null),
                    ],
                    selected: public,
                    onSelected: (v) => game.publicRoom.value = v ?? false,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(switch (mode) {
                GameMode.solo =>
                  'Du spielst allein gegen ${GameConfig.minBots} bis '
                      '${GameConfig.maxBots} CPU-Panzer, jede Runde neu '
                      'ausgewürfelt.',
                GameMode.multi =>
                  'Spiele mit anderen: Schick den Link weiter. Ein '
                      'öffentlicher Raum steht außerdem in der Raumliste.',
                GameMode.defense =>
                  'Gemeinsam gegen ${GameConfig.defenseWaves} Wellen, '
                      'allein oder mit anderen. Die Feinde rollen über die '
                      'Straße zum Stützpunkt. Für Abschüsse gibt es Mittel, '
                      'davon baust du Geschütze (Taste B). Munition gibt es am '
                      'Stützpunkt, zerstörte Panzer kehren nach kurzer Zeit '
                      'zurück.',
              }, style: const TextStyle(color: BwColors.textDim, fontSize: 12)),
              if (mode != GameMode.defense) ...[
                const SizedBox(height: 16),
                Text(
                  'CPU-GEGNER',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (mode == GameMode.multi) ...[
                  ValueListenableBuilder<bool>(
                    valueListenable: game.fillWithBots,
                    builder: (context, fill, _) => ChoiceRow<bool>(
                      options: const [
                        (false, 'NUR MENSCHEN', null),
                        (true, 'MIT CPU AUFFÜLLEN', null),
                      ],
                      selected: fill,
                      onSelected: (v) => game.fillWithBots.value = v ?? false,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                ValueListenableBuilder<BotLevel>(
                  valueListenable: game.botLevel,
                  builder: (context, level, _) => ChoiceRow<BotLevel>(
                    options: [
                      for (final option in BotLevel.values)
                        (option, option.label, null),
                    ],
                    selected: level,
                    onSelected: (v) => game.botLevel.value = v ?? level,
                  ),
                ),
                if (mode == GameMode.multi) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Auffüllen bringt das Feld auf ${GameConfig.fillTo} Panzer '
                    'und gleicht bei Teams die Seiten aus.',
                    style: TextStyle(color: BwColors.textDim, fontSize: 12),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _rosterColumn() {
    final game = widget.game;
    return ValueListenableBuilder<GameMode>(
      valueListenable: game.mode,
      builder: (context, mode, _) =>
          mode.withOthers ? _roster(game) : const SizedBox.shrink(),
    );
  }

  Widget _roster(SpaceGame game) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<List<LobbyPresence>>(
          valueListenable: game.roster,
          builder: (context, roster, _) => PlayerList(
            members: roster,
            myId: game.myId,
            colorOf: (member) =>
                game.lobbyColorOf(member.id, member.colorIndex),
          ),
        ),
      ],
    );
  }

  /// Closing takes two clicks: the first one asks, the second one closes.
  void _confirmClose() {
    if (_closeArmed) {
      _closeTimer?.cancel();
      widget.game.closeRoom();
      return;
    }
    setState(() => _closeArmed = true);
    _closeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _closeArmed = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // A guest stands in when the host leaves and hands back on return: the
    // whole lobby follows the role.
    return ValueListenableBuilder<bool>(
      valueListenable: widget.game.isHost,
      builder: (context, _, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.game.choosingMode,
      builder: (context, choosing, _) => ColoredBox(
        color: const Color(0xAA000000),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 720;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(narrow ? 8 : 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Panel(
                    padding: EdgeInsets.all(narrow ? 14 : 24),
                    child: choosing && widget.game.isHost.value
                        ? LaunchView(game: widget.game)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!widget.game.isHost.value)
                                const _JoinedBanner()
                              else ...[
                                _modeChoice(context),
                                ValueListenableBuilder<GameMode>(
                                  valueListenable: widget.game.mode,
                                  builder: (context, mode, _) => mode.withOthers
                                      ? Padding(
                                          padding: const EdgeInsets.only(
                                            top: 16,
                                          ),
                                          child: RoomInvite(game: widget.game),
                                        )
                                      : const SizedBox(),
                                ),
                              ],
                              const SizedBox(height: 24),
                              if (narrow) ...[
                                _pilotColumn(context),
                                const SizedBox(height: 24),
                                _rosterColumn(),
                              ] else
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _pilotColumn(context)),
                                    const SizedBox(width: 40),
                                    _rosterColumn(),
                                  ],
                                ),
                              if (roomLink(widget.game.net.room)
                                  .isNotEmpty) ...[
                                const SizedBox(height: 28),
                                RoomList(game: widget.game),
                              ],
                              const SizedBox(height: 28),
                              Leaderboard(game: widget.game),
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ColorSwatchButton extends StatelessWidget {
  const ColorSwatchButton({
    required this.color,
    required this.selected,
    required this.onTap,
    this.locked = false,
    super.key,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  /// Needs a higher rank: dimmed with a lock.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: locked ? color.withValues(alpha: 0.35) : color,
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(
              color: selected ? BwColors.amber : Colors.black45,
              width: 2.5,
            ),
          ),
        ),
        child: locked
            ? const Icon(Icons.lock, size: 14, color: Color(0xCCFFFFFF))
            : null,
      ),
    );
  }
}

/// Shown to players who joined by a link: no code, no settings, just waiting.
class _JoinedBanner extends StatelessWidget {
  const _JoinedBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x44000000),
        border: Border.all(color: BwColors.oliveLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top, color: BwColors.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Du bist dem Warteraum beigetreten. Der Gastgeber startet die '
                'Übung, sobald alle da sind.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
