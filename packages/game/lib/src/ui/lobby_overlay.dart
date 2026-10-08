import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
import 'widgets/account_sheet.dart';
import 'widgets/mute_button.dart';
import 'widgets/choice_row.dart';
import 'widgets/call_sign.dart';
import 'widgets/panel.dart';
import 'widgets/pilot_card.dart';
import 'widgets/room_invite.dart';
import 'widgets/player_list.dart';
import 'widgets/tank_choice.dart';
import 'widgets/tutorial_button.dart';
import '../l10n/l10n.dart';

class LobbyOverlay extends StatefulWidget {
  const LobbyOverlay({required this.game, super.key});

  final SpaceGame game;

  @override
  State<LobbyOverlay> createState() => _LobbyOverlayState();
}

class _LobbyOverlayState extends State<LobbyOverlay> {
  late int _colorIndex;
  late int _teamPick = widget.game.teamPick;
  bool _closeArmed = false;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _colorIndex = widget.game.myColorIndex;
    widget.game.pilotVersion.addListener(_reloadPilot);
  }

  /// Another account was signed in: show its look.
  void _reloadPilot() {
    setState(() => _colorIndex = widget.game.myColorIndex);
  }

  @override
  void dispose() {
    widget.game.pilotVersion.removeListener(_reloadPilot);
    _closeTimer?.cancel();
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
    widget.game.setPilot(name: widget.game.myName, colorIndex: _colorIndex);
  }

  /// Title, what the round is about and the sound switch.
  Widget _header(BuildContext context, String title) {
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
                  title,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
            ),
            AccountButton(game: game),
            const MuteButton(),
          ],
        ),
        const SizedBox(height: 4),
        ValueListenableBuilder<GameMode>(
          valueListenable: game.mode,
          builder: (context, mode, _) => Text(switch (mode) {
            GameMode.solo => tr(
              'Einzelspieler: Du gegen CPU-Panzer.',
              'Single player: You against CPU tanks.',
            ),
            GameMode.multi => tr(
              'Mehrspieler: Der letzte Panzer im Feld gewinnt.',
              'Multiplayer: The last tank in the field wins.',
            ),
            GameMode.defense => tr(
              'Verteidigung: Haltet den Stützpunkt gegen alle Wellen.',
              'Defense: Hold the base against all waves.',
            ),
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
      title: tr('RUNDE', 'ROUND'),
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
                        GameMode.solo => tr('EINZELSPIELER', 'SINGLE PLAYER'),
                        GameMode.multi => tr('MEHRSPIELER', 'MULTIPLAYER'),
                        GameMode.defense => tr('VERTEIDIGUNG', 'DEFENSE'),
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
                  label: Text(tr('ÄNDERN', 'CHANGE')),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _hint(switch (mode) {
              GameMode.solo => tr(
                'Du spielst allein gegen ${GameConfig.minBots} bis '
                    '${GameConfig.maxBots} CPU-Panzer, jede Runde neu '
                    'ausgewürfelt.',
                'You play alone against ${GameConfig.minBots} to '
                    '${GameConfig.maxBots} CPU tanks, rolled anew every round.',
              ),
              GameMode.multi => tr(
                'Den Link zum Einladen gibt es im Warteraum. Ein '
                    'öffentlicher Raum steht außerdem in der Raumliste der '
                    'Startseite.',
                'The link to invite others comes in the waiting room. A '
                    'public room is also listed in the room list on the '
                    'start page.',
              ),
              GameMode.defense => tr(
                'Die Feinde rollen über die Straße zum Stützpunkt, ab der '
                    'zweiten Welle auch aus der Luft. Abschüsse bringen '
                    'Mittel für Geschütze${game.touchMode.value ? '' : ' (B)'} '
                    'und Upgrades.',
                'The enemies roll down the road to the base, from the '
                    'second wave also through the air. Kills bring funds '
                    'for turrets${game.touchMode.value ? '' : ' (B)'} '
                    'and upgrades.',
              ),
            }),
            if (mode == GameMode.multi &&
                roomLink(game.net.room).isNotEmpty) ...[
              const SizedBox(height: 12),
              _label(context, tr('SICHTBARKEIT', 'VISIBILITY')),
              ValueListenableBuilder<bool>(
                valueListenable: game.publicRoom,
                builder: (context, public, _) => ChoiceRow<bool>(
                  options: [
                    (false, tr('PRIVAT', 'PRIVATE'), null),
                    (true, tr('ÖFFENTLICH', 'PUBLIC'), null),
                  ],
                  selected: public,
                  onSelected: (v) => game.publicRoom.value = v ?? false,
                ),
              ),
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
      title: tr('EINSATZ', 'MISSION'),
      child: ValueListenableBuilder<GameMode>(
        valueListenable: game.mode,
        builder: (context, mode, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(context, tr('SCHWIERIGKEIT', 'DIFFICULTY')),
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
                    BotLevel.easy => tr(
                      'Flaches Gelände, voller Tank und Munition ohne Ende. '
                          'CPU-Panzer zielen ungenau.',
                      'Flat terrain, a full tank and endless ammunition. '
                          'CPU tanks aim poorly.',
                    ),
                    BotLevel.normal => tr(
                      'Hügel bremsen bergauf. Munition und Treibstoff gehen '
                          'aus: Sammle Munitions-Gems und Kanister.',
                      'Hills slow you down uphill. Ammunition and fuel run '
                          'out: collect ammo gems and fuel cans.',
                    ),
                    BotLevel.hard => tr(
                      'Steile Hügel, knapper Nachschub und treffsichere '
                          'CPU-Panzer. Dazu gibt es Luftschläge als Gem, aber keine '
                          'Zielhilfe.',
                      'Steep hills, scarce supplies and sharp-shooting CPU '
                          'tanks. Air strikes come as gems, but there is no '
                          'aim assist.',
                    ),
                  }),
                ],
              ),
            ),
            if (mode == GameMode.multi) ...[
              const SizedBox(height: 14),
              _label(context, tr('CPU-PANZER', 'CPU TANKS')),
              ValueListenableBuilder<bool>(
                valueListenable: game.fillWithBots,
                builder: (context, fill, _) => ChoiceRow<bool>(
                  options: [
                    (false, tr('NUR MENSCHEN', 'HUMANS ONLY'), null),
                    (true, tr('MIT CPU AUFFÜLLEN', 'FILL WITH CPU'), null),
                  ],
                  selected: fill,
                  onSelected: (v) => game.fillWithBots.value = v ?? false,
                ),
              ),
              const SizedBox(height: 6),
              _hint(
                tr(
                  'Auffüllen bringt das Feld auf ${GameConfig.fillTo} Panzer '
                      'und gleicht bei Teams die Seiten aus.',
                  'Filling brings the field up to ${GameConfig.fillTo} tanks '
                      'and evens out the sides in teams.',
                ),
              ),
            ],
            if (mode != GameMode.defense) ...[
              const SizedBox(height: 14),
              _label(context, tr('MODUS', 'MODE')),
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
            options: [
              (false, tr('ALLE GEGEN ALLE', 'FREE FOR ALL'), null),
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
                (1, tr('ROT', 'RED'), GameConfig.teamColors[1]),
                (2, tr('BLAU', 'BLUE'), GameConfig.teamColors[2]),
              ],
              selected: _teamPick,
              onSelected: (v) {
                setState(() => _teamPick = v ?? 0);
                game.setTeamPick(_teamPick);
              },
            ),
            const SizedBox(height: 6),
            _hint(
              tr(
                'AUTO füllt das kleinere Team. Eigene Teammitglieder und '
                    'Trupps triffst du nicht.',
                'AUTO fills the smaller team. You do not hit your own '
                    'teammates and squads.',
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The ground. Host only.
  Widget _fieldSection(BuildContext context) {
    final game = widget.game;
    return _Section(
      icon: Icons.landscape_outlined,
      title: tr('GELÄNDE', 'TERRAIN'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context, tr('GELÄNDE', 'TERRAIN')),
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
          const SizedBox(height: 6),
          _hint(
            tr(
              'Ohne Auswahl wird zufällig bestimmt. Tag und Nacht wechseln '
                  'sich regelmäßig ab, das Wetter würfelt jede Runde selbst aus und '
                  'schlägt in langen Runden um. Nachts, im Nebel und im Sandsturm '
                  'siehst du nur, was nah ist.',
              'Without a choice it is picked at random. Day and night '
                  'alternate regularly, the weather rolls itself every round '
                  'and changes in long rounds. At night, in fog and in a '
                  'sandstorm you only see what is close.',
            ),
          ),
        ],
      ),
    );
  }

  /// What the host set up, in short, with the way back to change it.
  Widget _summarySection(BuildContext context) {
    final game = widget.game;
    return ListenableBuilder(
      listenable: Listenable.merge([
        game.mode,
        game.botLevel,
        game.fillWithBots,
        game.teamMode,
        game.mapChoice,
        game.publicRoom,
      ]),
      builder: (context, _) {
        final mode = game.mode.value;
        final map = game.mapChoice.value;
        final facts = [
          switch (mode) {
            GameMode.solo => tr('EINZELSPIELER', 'SINGLE PLAYER'),
            GameMode.multi => tr('MEHRSPIELER', 'MULTIPLAYER'),
            GameMode.defense => tr('VERTEIDIGUNG', 'DEFENSE'),
          },
          game.botLevel.value.label,
          if (mode == GameMode.multi)
            game.fillWithBots.value
                ? tr('MIT CPU AUFFÜLLEN', 'FILL WITH CPU')
                : tr('NUR MENSCHEN', 'HUMANS ONLY'),
          if (mode != GameMode.defense)
            game.teamMode.value
                ? 'TEAMS'
                : tr('ALLE GEGEN ALLE', 'FREE FOR ALL'),
          map == null
              ? tr('ZUFÄLLIGES GELÄNDE', 'RANDOM TERRAIN')
              : MapTheme.all[map].name.toUpperCase(),
          if (mode == GameMode.multi && roomLink(game.net.room).isNotEmpty)
            game.publicRoom.value
                ? tr('ÖFFENTLICH', 'PUBLIC')
                : tr('PRIVAT', 'PRIVATE'),
        ];
        return _Section(
          icon: Icons.tune,
          title: tr('EINSTELLUNGEN', 'SETTINGS'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final fact in facts) _Fact(fact)],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: game.editSettings,
                icon: const Icon(Icons.edit_outlined),
                label: Text(tr('ÄNDERN', 'CHANGE')),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Call sign, vehicle and paint: what every player sets. The call sign
  /// and the account are changed behind the profile button.
  Widget _tankSection(BuildContext context) {
    final game = widget.game;
    return _Section(
      icon: Icons.shield_outlined,
      title: tr('DEIN PANZER', 'YOUR TANK'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PilotCard(progress: game.progress),
          const SizedBox(height: 12),
          CallSign(game: game),
          _label(context, tr('FAHRZEUG', 'VEHICLE')),
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
                    for (final type in StatBars.ordered(
                      game.progress.vehicleUnlocked,
                    ))
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
                    tr(
                      'Mit anderen fährt jeder Panzer in einer eigenen Farbe '
                          'statt in Tarnung.',
                      'With others every tank drives in its own colour '
                          'instead of camouflage.',
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(context, tr('TARNUNG', 'CAMOUFLAGE')),
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
                                    ? GameConfig.colorName(i)
                                    : '${GameConfig.colorName(i)}: '
                                          '${tr('ab Stufe', 'from level')} '
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
    return _Section(
      // The list brings its own heading.
      child: ValueListenableBuilder<List<LobbyPresence>>(
        valueListenable: game.roster,
        builder: (context, roster, _) => PlayerList(
          members: roster,
          myId: game.myId,
          colorOf: (member) => game.lobbyColorOf(member.id, member.colorIndex),
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
                game.canStart
                    ? tr('GEFECHT STARTEN', 'START BATTLE')
                    : tr('WARTE AUF GASTGEBER', 'WAITING FOR HOST'),
              ),
            ),
            if (live != null)
              OutlinedButton.icon(
                onPressed: game.spectateLiveMatch,
                icon: const Icon(Icons.visibility),
                label: Text(
                  tr(
                    'LAUFENDES GEFECHT BEOBACHTEN',
                    'WATCH THE BATTLE IN PROGRESS',
                  ),
                ),
              ),
            ValueListenableBuilder(
              valueListenable: game.lastReplay,
              builder: (context, replay, _) => replay == null
                  ? const SizedBox.shrink()
                  : OutlinedButton.icon(
                      onPressed: game.watchReplay,
                      icon: const Icon(Icons.movie_outlined),
                      label: Text(
                        tr('LETZTE RUNDE ANSEHEN', 'WATCH LAST ROUND'),
                      ),
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
                (true, true) => tr(
                  'WIRKLICH FÜR ALLE SCHLIESSEN?',
                  'REALLY CLOSE FOR EVERYONE?',
                ),
                (true, false) => tr('WIRKLICH VERLASSEN?', 'REALLY LEAVE?'),
                (false, true) => tr(
                  'WARTERAUM SCHLIESSEN',
                  'CLOSE WAITING ROOM',
                ),
                (false, false) => tr(
                  'WARTERAUM VERLASSEN',
                  'LEAVE WAITING ROOM',
                ),
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
          title: Text(
            tr('STEUERUNG', 'CONTROLS'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _hint(
              touch
                  ? tr(
                      'Linker Stick fährt: nach oben vorwärts, zur Seite lenken. '
                          'Rechter Stick richtet den Turm aus und feuert, sobald '
                          'du über den Ring schiebst. Kisten und Gems landen im '
                          'Inventar am linken Rand, ein Tipp setzt sie ein. '
                          'Waffen wie Granatwerfer, Mörser und Drohne löst du '
                          'danach mit dem runden Knopf über dem rechten Stick aus.',
                      'The left stick drives: up for forward, sideways to '
                          'steer. The right stick aims the turret and fires '
                          'as soon as you push past the ring. Crates and gems '
                          'land in the inventory on the left edge, a tap uses '
                          'them. Weapons such as grenade launcher, mortar and '
                          'drone are then fired with the round button above '
                          'the right stick.',
                    )
                  : tr(
                      'Fahren mit WASD oder Pfeiltasten, der Turm zielt auf die '
                          'Maus (oder Q und E), Feuer mit Leertaste oder '
                          'Linksklick. Kisten und Gems wandern ins Inventar am '
                          'linken Rand, du setzt sie mit 1 bis 6 oder einem Klick '
                          'ein. Waffen löst du danach mit F aus. In der '
                          'Verteidigung baut B ein Geschütz, V wechselt den Typ.',
                      'Drive with WASD or the arrow keys, the turret aims at '
                          'the mouse (or Q and E), fire with space or left '
                          'click. Crates and gems go to the inventory on the '
                          'left edge, use them with 1 to 6 or a click. '
                          'Weapons are then fired with F. In defense, B builds '
                          'a turret and V switches the type.',
                    ),
            ),
            const SizedBox(height: 4),
            TutorialButton(game: game),
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

  Widget _column(List<Widget> parts) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, part) in parts.indexed) ...[
        if (i > 0) const SizedBox(height: 14),
        part,
      ],
    ],
  );

  /// Two columns side by side, or one after the other on a narrow screen.
  Widget _columns(
    List<Widget> left,
    List<Widget> right, {
    required bool narrow,
  }) {
    if (narrow) {
      return _column([...left, ...right]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _column(left)),
        const SizedBox(width: 16),
        Expanded(child: _column(right)),
      ],
    );
  }

  /// First step for the host: how the round goes. Nobody sees the room in
  /// the public list yet.
  Widget _settings(BuildContext context, {required bool narrow}) {
    final game = widget.game;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, tr('EINSTELLUNGEN', 'SETTINGS')),
        const SizedBox(height: 18),
        if (narrow)
          _column([
            _roundSection(context),
            _battleSection(context),
            _fieldSection(context),
          ])
        else
          _columns(
            [_roundSection(context), _fieldSection(context)],
            [_battleSection(context)],
            narrow: narrow,
          ),
        const SizedBox(height: 18),
        ValueListenableBuilder<GameMode>(
          valueListenable: game.mode,
          builder: (context, mode, _) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: game.openWaitingRoom,
                icon: Icon(
                  mode.withOthers
                      ? Icons.meeting_room_outlined
                      : Icons.chevron_right,
                ),
                label: Text(
                  mode.withOthers
                      ? tr('WARTERAUM ÖFFNEN', 'OPEN WAITING ROOM')
                      : tr('WEITER', 'CONTINUE'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: game.changeMode,
                icon: const Icon(Icons.arrow_back),
                label: Text(tr('ZURÜCK', 'BACK')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Second step: who is here, the player's own tank and the start. The
  /// host sees the settings in short, guests that they wait for the host.
  Widget _room(BuildContext context, {required bool narrow}) {
    final host = widget.game.isHost.value;
    return ValueListenableBuilder<GameMode>(
      valueListenable: widget.game.mode,
      builder: (context, mode, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(
            context,
            mode.withOthers
                ? tr('WARTERAUM', 'WAITING ROOM')
                : tr('BEREITSTELLUNG', 'GET READY'),
          ),
          const SizedBox(height: 18),
          _columns(
            [
              if (host) _summarySection(context) else const _JoinedBanner(),
              if (mode.withOthers) ...[
                if (host) RoomInvite(game: widget.game),
                _crewSection(),
              ],
            ],
            [_tankSection(context)],
            narrow: narrow,
          ),
          const SizedBox(height: 18),
          _actions(),
          const SizedBox(height: 8),
          _controls(),
        ],
      ),
    );
  }

  Widget _frame({
    required bool phone,
    required bool narrow,
    required Widget child,
  }) {
    if (phone) {
      return Padding(padding: const EdgeInsets.all(8), child: child);
    }
    return Panel(padding: EdgeInsets.all(narrow ? 14 : 24), child: child);
  }

  /// Phones and the apps on tablets show the menu without the outer plate:
  /// the screen edge already frames it.
  bool _frameless(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600 ||
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android));

  Widget _build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.game.choosingMode,
        widget.game.configuring,
        widget.game.welcomed,
      ]),
      builder: (context, _) => ColoredBox(
        // Without the plate on phones the backdrop carries the contrast.
        color: _frameless(context) ? BwColors.panel : const Color(0xAA000000),
        // Keeps the menu clear of the notch and the Dynamic Island on
        // phones held sideways, the backdrop still covers the whole screen.
        // Phones scroll the page up to the lower screen edge instead of
        // cutting it off above the home indicator.
        child: SafeArea(
          bottom: !_frameless(context),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 820;
              final phone = _frameless(context);
              final host = widget.game.isHost.value;
              final page = !widget.game.welcomed.value
                  ? 0
                  : widget.game.choosingMode.value && host
                  ? 1
                  : widget.game.configuring.value && host
                  ? 2
                  : 3;
              return Center(
                child: SingleChildScrollView(
                  // A fresh scroll position per page, so the waiting room
                  // opens at its top and not where the start page was left.
                  key: ValueKey(page),
                  padding: phone
                      ? EdgeInsets.fromLTRB(
                          8,
                          8,
                          8,
                          8 + MediaQuery.paddingOf(context).bottom,
                        )
                      : EdgeInsets.all(narrow ? 8 : 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: _frame(
                      // Phones show the menu without the outer plate: the
                      // screen edge already frames it.
                      phone: phone,
                      narrow: narrow,
                      child: switch (page) {
                        0 => WelcomeView(game: widget.game),
                        1 => LaunchView(game: widget.game),
                        2 => _settings(context, narrow: narrow),
                        _ => _room(context, narrow: narrow),
                      },
                    ),
                  ),
                ),
              );
            },
          ),
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
        color: const Color(0x44000000),
        shape: BwShapes.card(),
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

/// One setting in the summary, as a small framed tag.
class _Fact extends StatelessWidget {
  const _Fact(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: const Color(0x33000000),
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: BwColors.sand, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: BwColors.sand,
          ),
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
      decoration: ShapeDecoration(
        color: const Color(0x44000000),
        shape: BwShapes.card(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top, color: BwColors.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr(
                  'Du bist dem Warteraum beigetreten. Der Gastgeber startet das '
                      'Gefecht, sobald alle da sind.',
                  'You joined the waiting room. The host starts the battle '
                      'as soon as everyone is here.',
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
