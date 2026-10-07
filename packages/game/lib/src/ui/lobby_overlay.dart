import 'dart:async';

import 'package:flutter/material.dart';

import '../env.dart';
import '../game_config.dart';
import '../game/bot_level.dart';
import '../game/game_mode.dart';
import '../game/map_theme.dart';
import '../game/space_game.dart';
import '../net/payloads/lobby_presence.dart';
import '../net/room.dart';
import '../game/components/tank_painter.dart';
import '../theme.dart';
import 'launch_view.dart';
import 'welcome_view.dart';
import 'widgets/mute_button.dart';
import 'widgets/choice_row.dart';
import 'widgets/account_panel.dart';
import 'widgets/panel.dart';
import 'widgets/pilot_card.dart';
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
    final progress = widget.game.progress;
    if (color != null && !progress.unlocked(color)) {
      return;
    }
    if (type != null && !progress.vehicleUnlocked(TankType.values[type])) {
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

  /// Title, what the round is about and the sound switch.
  Widget _header(BuildContext context) {
    final game = widget.game;
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
                  'WARTERAUM',
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
          builder: (context, mode, _) => Text(switch (mode) {
            GameMode.solo => 'Einzelspieler: Du gegen CPU-Panzer.',
            GameMode.multi => 'Mehrspieler: Der letzte Panzer im Feld gewinnt.',
            GameMode.defense =>
              'Verteidigung: Haltet den Stützpunkt gegen alle Wellen.',
          }, style: const TextStyle(color: BwColors.textDim)),
        ),
      ],
    );
  }

  /// Way to play, who may join and the link to share. Host only.
  Widget _roundSection(BuildContext context) {
    final game = widget.game;
    return _Section(
      icon: Icons.flag_outlined,
      title: 'RUNDE',
      child: ValueListenableBuilder<GameMode>(
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
            const SizedBox(height: 6),
            _hint(switch (mode) {
              GameMode.solo =>
                'Du spielst allein gegen ${GameConfig.minBots} bis '
                    '${GameConfig.maxBots} CPU-Panzer, jede Runde neu '
                    'ausgewürfelt.',
              GameMode.multi =>
                'Schick den Link weiter. Ein öffentlicher Raum steht '
                    'außerdem in der Raumliste der Startseite.',
              GameMode.defense =>
                'Die Feinde rollen über die Straße zum Stützpunkt, ab der '
                    'zweiten Welle auch aus der Luft. Abschüsse bringen '
                    'Mittel für Geschütze (B) und Upgrades.',
            }),
            if (mode == GameMode.multi &&
                roomLink(game.net.room).isNotEmpty) ...[
              const SizedBox(height: 12),
              _label(context, 'SICHTBARKEIT'),
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
            if (mode.withOthers) ...[
              const SizedBox(height: 12),
              RoomInvite(game: game),
            ],
          ],
        ),
      ),
    );
  }

  /// Difficulty, CPU tanks and teams. Host only.
  Widget _battleSection(BuildContext context) {
    final game = widget.game;
    return _Section(
      icon: Icons.tune,
      title: 'EINSATZ',
      child: ValueListenableBuilder<GameMode>(
        valueListenable: game.mode,
        builder: (context, mode, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(context, 'SCHWIERIGKEIT'),
            ValueListenableBuilder<BotLevel>(
              valueListenable: game.botLevel,
              builder: (context, level, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChoiceRow<BotLevel>(
                    options: [
                      for (final option in BotLevel.values)
                        (option, option.label, null),
                    ],
                    selected: level,
                    onSelected: (v) => game.botLevel.value = v ?? level,
                  ),
                  const SizedBox(height: 6),
                  _hint(switch (level) {
                    BotLevel.easy =>
                      'Flaches Gelände, voller Tank und Munition ohne Ende. '
                          'CPU-Panzer zielen ungenau.',
                    BotLevel.normal =>
                      'Hügel bremsen bergauf. Munition und Treibstoff gehen '
                          'aus: Sammle Munitions-Gems und Kanister.',
                    BotLevel.hard =>
                      'Steile Hügel, knapper Nachschub und treffsichere '
                          'CPU-Panzer. Dazu gibt es Luftschläge als Gem.',
                  }),
                ],
              ),
            ),
            if (mode == GameMode.multi) ...[
              const SizedBox(height: 14),
              _label(context, 'CPU-PANZER'),
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
              const SizedBox(height: 6),
              _hint(
                'Auffüllen bringt das Feld auf ${GameConfig.fillTo} Panzer '
                'und gleicht bei Teams die Seiten aus.',
              ),
            ],
            if (mode != GameMode.defense) ...[
              const SizedBox(height: 14),
              _label(context, 'MODUS'),
              _teamChoice(),
            ],
          ],
        ),
      ),
    );
  }

  /// Free for all or red against blue, and the side the host takes.
  Widget _teamChoice() {
    final game = widget.game;
    return ValueListenableBuilder<bool>(
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
            _hint(
              'AUTO füllt das kleinere Team. Eigene Teammitglieder und '
              'Trupps triffst du nicht.',
            ),
          ],
        ],
      ),
    );
  }

  /// Ground, weather and time of day. Host only.
  Widget _fieldSection(BuildContext context) {
    final game = widget.game;
    return _Section(
      icon: Icons.landscape_outlined,
      title: 'GELÄNDE & TAGESZEIT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context, 'GELÄNDE'),
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
          const SizedBox(height: 14),
          _label(context, 'TAGESZEIT'),
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
          _hint(
            'Ohne Auswahl wird zufällig bestimmt. Das Wetter würfelt jede '
            'Runde selbst aus, in langen Runden schlägt es um. Nachts, im '
            'Nebel und im Sandsturm siehst du nur, was nah ist.',
          ),
        ],
      ),
    );
  }

  /// Call sign, account, vehicle and paint: what every player sets.
  Widget _tankSection(BuildContext context) {
    final game = widget.game;
    return _Section(
      icon: Icons.shield_outlined,
      title: 'DEIN PANZER',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PilotCard(progress: game.progress),
          if (Env.accounts) ...[
            const SizedBox(height: 8),
            AccountPanel(
              accounts: game.accounts,
              onCallSign: (name) {
                game.claimCallSign(name);
                setState(() => _nameController.text = name);
              },
              callSign: game.myName,
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            maxLength: 16,
            decoration: const InputDecoration(labelText: 'RUFNAME'),
            onChanged: (_) => _apply(),
          ),
          _label(context, 'FAHRZEUG'),
          ListenableBuilder(
            listenable: Listenable.merge([
              game.roster,
              game.mode,
              game.progress.rank,
            ]),
            builder: (context, _) => LayoutBuilder(
              builder: (context, box) {
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
                        locked: !game.progress.vehicleUnlocked(type),
                        onTap: () => _pick(type: type.index),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          StatBars(type: GameConfig.typeOf(_colorIndex)),
          const SizedBox(height: 14),
          ValueListenableBuilder<GameMode>(
            valueListenable: game.mode,
            builder: (context, mode, _) => mode.withOthers
                ? _hint(
                    'Mit anderen fährt jeder Panzer in einer eigenen Farbe '
                    'statt in Tarnung.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(context, 'TARNUNG'),
                      ValueListenableBuilder(
                        valueListenable: game.progress.rank,
                        builder: (context, rank, _) => Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (
                              var i = 0;
                              i < GameConfig.shipColors.length;
                              i++
                            )
                              Tooltip(
                                message: game.progress.unlocked(i)
                                    ? GameConfig.colorNames[i]
                                    : '${GameConfig.colorNames[i]}: ab Stufe '
                                          '${GameConfig.colorLevels[i]}',
                                child: ColorSwatchButton(
                                  color: GameConfig.shipColors[i],
                                  selected:
                                      i ==
                                      _colorIndex %
                                          GameConfig.shipColors.length,
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
        ],
      ),
    );
  }

  /// Who is in the room, when playing with others.
  Widget _crewSection() {
    final game = widget.game;
    return ValueListenableBuilder<GameMode>(
      valueListenable: game.mode,
      builder: (context, mode, _) => !mode.withOthers
          ? const SizedBox.shrink()
          : _Section(
              // The list brings its own heading.
              child: ValueListenableBuilder<List<LobbyPresence>>(
                valueListenable: game.roster,
                builder: (context, roster, _) => PlayerList(
                  members: roster,
                  myId: game.myId,
                  colorOf: (member) =>
                      game.lobbyColorOf(member.id, member.colorIndex),
                ),
              ),
            ),
    );
  }

  /// Start, watch, replay and leave.
  Widget _actions() {
    final game = widget.game;
    return ValueListenableBuilder<List<LobbyPresence>>(
      valueListenable: game.roster,
      builder: (context, roster, _) {
        final live = game.liveMatch;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
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
    );
  }

  /// How to steer, folded away until asked for.
  Widget _controls() {
    final game = widget.game;
    return ValueListenableBuilder<bool>(
      valueListenable: game.touchMode,
      builder: (context, touch, _) => Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          leading: const Icon(Icons.sports_esports, color: BwColors.amber),
          title: const Text(
            'STEUERUNG',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5),
          ),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _hint(
              touch
                  ? 'Linker Stick fährt: nach oben vorwärts, zur Seite lenken. '
                        'Rechter Stick richtet den Turm aus und feuert, sobald '
                        'du über den Ring schiebst. Kisten und Gems landen im '
                        'Inventar am linken Rand, ein Tipp setzt sie ein. '
                        'Waffen wie Granatwerfer, Mörser und Drohne löst du '
                        'danach mit dem runden Knopf über dem rechten Stick aus.'
                  : 'Fahren mit WASD oder Pfeiltasten, der Turm zielt auf die '
                        'Maus (oder Q und E), Feuer mit Leertaste oder '
                        'Linksklick. Kisten und Gems wandern ins Inventar am '
                        'linken Rand, du setzt sie mit 1 bis 6 oder einem Klick '
                        'ein. Waffen löst du danach mit F aus. In der '
                        'Verteidigung baut B ein Geschütz, V wechselt den Typ.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: BwColors.sand,
      ),
    ),
  );

  Widget _hint(String text) =>
      Text(text, style: const TextStyle(color: BwColors.textDim, fontSize: 12));

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

  /// The waiting room: the round on the left, the player's own tank on the
  /// right, the buttons at the bottom. On a narrow screen one after the
  /// other.
  Widget _room(BuildContext context, {required bool narrow}) {
    final host = widget.game.isHost.value;
    final settings = <Widget>[
      if (host) ...[
        _roundSection(context),
        _battleSection(context),
        _fieldSection(context),
      ] else
        const _JoinedBanner(),
    ];
    final mine = <Widget>[_tankSection(context), _crewSection()];
    Widget column(List<Widget> parts) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, part) in parts.indexed) ...[
          if (i > 0) const SizedBox(height: 14),
          part,
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context),
        const SizedBox(height: 18),
        if (narrow)
          column([...settings, ...mine])
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: column(settings)),
              const SizedBox(width: 16),
              Expanded(child: column(mine)),
            ],
          ),
        const SizedBox(height: 18),
        _actions(),
        const SizedBox(height: 8),
        _controls(),
      ],
    );
  }

  Widget _build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.game.choosingMode,
        widget.game.welcomed,
      ]),
      builder: (context, _) => ColoredBox(
        color: const Color(0xAA000000),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 820;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(narrow ? 8 : 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Panel(
                    padding: EdgeInsets.all(narrow ? 14 : 24),
                    child: !widget.game.welcomed.value
                        ? WelcomeView(game: widget.game)
                        : widget.game.choosingMode.value &&
                              widget.game.isHost.value
                        ? LaunchView(game: widget.game)
                        : _room(context, narrow: narrow),
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

/// A group of settings under a heading, set off by a thin frame.
class _Section extends StatelessWidget {
  const _Section({required this.child, this.icon, this.title});

  final IconData? icon;
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: const Color(0x33000000),
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Color(0x888A9A5B)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Icon(icon, size: 18, color: BwColors.amber),
                  const SizedBox(width: 8),
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(letterSpacing: 2),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            child,
          ],
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
