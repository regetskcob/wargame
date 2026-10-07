import 'package:flutter/material.dart';

import '../game_config.dart';
import '../game/map_theme.dart';
import '../game/space_game.dart';
import '../net/payloads/lobby_presence.dart';
import '../game/components/tank_painter.dart';
import '../theme.dart';
import 'widgets/mute_button.dart';
import 'widgets/leaderboard.dart';
import 'widgets/panel.dart';
import 'widgets/room_invite.dart';
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.game.myName);
    _colorIndex = widget.game.myColorIndex;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _pick({int? type, int? color}) {
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
              child: Text(
                'PANZERGEFECHT',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
            const MuteButton(),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Gefechtsübung: Der letzte Panzer im Feld gewinnt.',
          style: TextStyle(color: BwColors.textDim),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          maxLength: 16,
          decoration: const InputDecoration(labelText: 'RUFNAME'),
          onChanged: (_) => _apply(),
        ),
        const SizedBox(height: 8),
        Text('FAHRZEUG', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in TankType.values)
              TankChoice(
                type: type,
                color: GameConfig.colorOf(_colorIndex),
                selected: type == GameConfig.typeOf(_colorIndex),
                onTap: () => _pick(type: type.index),
              ),
          ],
        ),
        const SizedBox(height: 12),
        StatBars(type: GameConfig.typeOf(_colorIndex)),
        const SizedBox(height: 16),
        Text('TARNUNG', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < GameConfig.shipColors.length; i++)
              Tooltip(
                message: GameConfig.colorNames[i],
                child: ColorSwatchButton(
                  color: GameConfig.shipColors[i],
                  selected: i == _colorIndex % GameConfig.shipColors.length,
                  onTap: () => _pick(color: i),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('MODUS', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ValueListenableBuilder<bool>(
          valueListenable: game.teamMode,
          builder: (context, teams, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('ALLE GEGEN ALLE')),
                  ButtonSegment(value: true, label: Text('TEAMS')),
                ],
                selected: {teams},
                onSelectionChanged: (s) => game.teamMode.value = s.first,
              ),
              if (teams) ...[
                const SizedBox(height: 10),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    const ButtonSegment(value: 0, label: Text('AUTO')),
                    ButtonSegment(
                      value: 1,
                      label: Text(
                        'ROT',
                        style: TextStyle(color: GameConfig.teamColors[1]),
                      ),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text(
                        'BLAU',
                        style: TextStyle(color: GameConfig.teamColors[2]),
                      ),
                    ),
                  ],
                  selected: {_teamPick},
                  onSelectionChanged: (s) {
                    setState(() => _teamPick = s.first);
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
        const SizedBox(height: 16),
        Text('CPU-GEGNER', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        ValueListenableBuilder<int>(
          valueListenable: game.botCount,
          builder: (context, count, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.outlined(
                tooltip: 'Weniger',
                onPressed: count > 0
                    ? () => game.botCount.value = count - 1
                    : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton.outlined(
                tooltip: 'Mehr',
                onPressed: count < 6
                    ? () => game.botCount.value = count + 1
                    : null,
                icon: const Icon(Icons.add),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  count == 0 ? 'Nur echte Spieler.' : 'Läuft auf deinem Gerät: Das Fenster muss offen bleiben.',
                  style: const TextStyle(color: BwColors.textDim, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('GELÄNDE', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ValueListenableBuilder<int?>(
          valueListenable: game.mapChoice,
          builder: (context, choice, _) => SegmentedButton<int>(
            showSelectedIcon: false,
            emptySelectionAllowed: true,
            segments: [
              for (var i = 0; i < MapTheme.all.length; i++)
                ButtonSegment(
                  value: i,
                  label: Text(MapTheme.all[i].name.toUpperCase()),
                ),
            ],
            selected: {?choice},
            onSelectionChanged: (s) =>
                game.mapChoice.value = s.isEmpty ? null : s.first,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Ohne Auswahl wird das Gelände zufällig bestimmt.',
          style: TextStyle(color: BwColors.textDim, fontSize: 12),
        ),
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
                  onPressed: live == null
                      ? () {
                          _apply();
                          game.startRound();
                        }
                      : null,
                  icon: const Icon(Icons.flag),
                  label: const Text('ÜBUNG STARTEN'),
                ),
                if (live != null)
                  OutlinedButton.icon(
                    onPressed: game.spectateLiveMatch,
                    icon: const Icon(Icons.visibility),
                    label: const Text('LAUFENDE ÜBUNG BEOBACHTEN'),
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

  Widget _rosterColumn() {
    final game = widget.game;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<List<LobbyPresence>>(
          valueListenable: game.roster,
          builder: (context, roster, _) =>
              PlayerList(members: roster, myId: game.myId),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xAA000000),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 720;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Panel(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RoomInvite(game: widget.game),
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
    );
  }
}

class ColorSwatchButton extends StatelessWidget {
  const ColorSwatchButton({
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: ShapeDecoration(
          color: color,
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(
              color: selected ? BwColors.amber : Colors.black45,
              width: 2.5,
            ),
          ),
        ),
      ),
    );
  }
}
