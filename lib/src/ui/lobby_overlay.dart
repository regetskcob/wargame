import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/game_config.dart';
import '../game/bot_level.dart';
import '../game/game_mode.dart';
import '../game/map_theme.dart';
import '../game/tank_game.dart';
import '../net/payloads/lobby_presence.dart';
import '../game/components/tank_painter.dart';
import 'theme.dart';
import 'launch_view.dart';
import 'welcome_view.dart';
import 'widgets/account_sheet.dart';
import 'widgets/mute_button.dart';
import 'widgets/rooms_busy_notice.dart';
import 'widgets/server_notice.dart';
import 'widgets/choice_row.dart';
import 'widgets/fit_or_scroll.dart';
import 'widgets/panel.dart';
import 'widgets/room_invite.dart';
import 'widgets/player_list.dart';
import 'widgets/tank_choice.dart';
import '../l10n/l10n.dart';
import '../tv/tv_input.dart';

class LobbyOverlay extends StatefulWidget {
  const LobbyOverlay({required this.game, super.key});

  final TankGame game;

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
        color ?? _colorIndex % GameConfig.tankColors.length,
      );
    });
    _apply();
  }

  void _apply() {
    widget.game.setPilot(name: widget.game.myName, colorIndex: _colorIndex);
  }

  /// Title, what the round is about and the sound switch.
  Widget _header(
    BuildContext context,
    String title, {
    List<Widget> extra = const [],
  }) {
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
            ...extra,
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
              ListenableBuilder(
                listenable: Listenable.merge([game.roster, game.padSteered]),
                builder: (context, _) => game.roomHasPhone
                    ? Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          tr(
                            'Mit Handy-Controller im Raum ohne CPU-Panzer, '
                                'damit der Server beides trägt.',
                            'With a phone controller in the room there are no '
                                'CPU tanks, so the server carries both.',
                          ),
                          style: const TextStyle(
                            color: BwColors.textDim,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
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
                'AUTO füllt das kleinere Team.',
                'AUTO fills the smaller team.',
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
              'Ohne Auswahl zufällig. Wetter und Tageszeit wechseln von '
                  'selbst.',
              'Random without a choice. Weather and time of day change by '
                  'themselves.',
            ),
          ),
        ],
      ),
    );
  }

  /// The vehicles the player may drive, and the next one to earn. The
  /// rest stays out of sight until it comes closer.
  List<TankType> _offeredVehicles() {
    final unlocked = widget.game.progress.vehicleUnlocked;
    final all = StatBars.ordered(unlocked);
    return [...all.where(unlocked), ...all.where((t) => !unlocked(t)).take(1)];
  }

  /// Vehicle and paint: what every player sets.
  Widget _tankSection(BuildContext context) {
    final game = widget.game;
    return _Section(
      icon: Icons.shield_outlined,
      title: tr('DEIN PANZER', 'YOUR TANK'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    for (final type in _offeredVehicles())
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
            // With others every tank drives in its own colour.
            builder: (context, mode, _) => mode.withOthers
                ? const SizedBox.shrink()
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
                              i < GameConfig.tankColors.length;
                              i++
                            )
                              Tooltip(
                                message: game.progress.unlocked(i)
                                    ? GameConfig.colorName(i)
                                    : '${GameConfig.colorName(i)}: '
                                          '${tr('ab Stufe', 'from level')} '
                                          '${GameConfig.colorLevels[i]}',
                                child: ColorSwatchButton(
                                  color: GameConfig.tankColors[i],
                                  selected:
                                      i ==
                                      _colorIndex %
                                          GameConfig.tankColors.length,
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

  /// Watch and replay above, then leave on the left and start on the
  /// right, both as wide.
  Widget _actions() {
    final game = widget.game;
    return ValueListenableBuilder<List<LobbyPresence>>(
      valueListenable: game.roster,
      builder: (context, roster, _) {
        final live = game.liveMatch;
        final Widget leave;
        // Alone there is nobody to close the room for: just go back.
        if (game.mode.value == GameMode.solo && game.isHost.value) {
          leave = OutlinedButton.icon(
            onPressed: game.changeMode,
            icon: const Icon(Icons.arrow_back),
            label: _oneLine(tr('ZURÜCK', 'BACK')),
          );
        } else {
          leave = OutlinedButton.icon(
            onPressed: _confirmClose,
            style: _closeArmed
                ? OutlinedButton.styleFrom(
                    foregroundColor: BwColors.danger,
                    side: const BorderSide(color: BwColors.danger),
                  )
                : null,
            icon: Icon(_closeArmed ? Icons.warning_amber : Icons.close),
            label: _oneLine(switch ((_closeArmed, game.isHost.value)) {
              (true, true) => tr(
                'WIRKLICH FÜR ALLE SCHLIESSEN?',
                'REALLY CLOSE FOR EVERYONE?',
              ),
              (true, false) => tr('WIRKLICH VERLASSEN?', 'REALLY LEAVE?'),
              (false, true) => tr('WARTERAUM SCHLIESSEN', 'CLOSE WAITING ROOM'),
              (false, false) => tr('WARTERAUM VERLASSEN', 'LEAVE WAITING ROOM'),
            }),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder(
              valueListenable: game.lastReplay,
              builder: (context, replay, _) => live == null && replay == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
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
                          if (replay != null)
                            OutlinedButton.icon(
                              onPressed: game.watchReplay,
                              icon: const Icon(Icons.movie_outlined),
                              label: Text(
                                tr('LETZTE RUNDE ANSEHEN', 'WATCH LAST ROUND'),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            Row(
              children: [
                Expanded(child: leave),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: live == null && game.canStart
                        ? () {
                            _apply();
                            game.startRound();
                          }
                        : null,
                    icon: const Icon(Icons.flag),
                    label: _oneLine(
                      game.canStart
                          ? tr('STARTEN', 'START')
                          : tr('WARTE AUF GASTGEBER', 'WAITING FOR HOST'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// A button label on one line, shrinking where the half width is too
  /// narrow, so both buttons in the row stay as tall.
  Widget _oneLine(String text) =>
      FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1));

  /// How to steer, behind the question mark in the heading, with the way
  /// into the briefing.
  void _showControls(BuildContext context) {
    final game = widget.game;
    final touch = game.touchMode.value;
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: BwColors.surface,
        title: Text(tr('STEUERUNG', 'CONTROLS')),
        content: Text(
          onTv
              ? tr(
                  'Controller: Linker Stick fährt, rechter Stick zielt, R2 '
                      'oder A feuert, L2 löst Waffen wie Granatwerfer, Mörser '
                      'und Drohne aus. X, Y und das Steuerkreuz setzen das '
                      'Inventar am linken Rand ein. In der Verteidigung baut '
                      'R1 ein Geschütz, L1 wechselt den Typ. Siri Remote: Der '
                      'Daumen auf der Touchfläche zeigt die Fahrtrichtung, '
                      'die Zielhilfe zielt, ein Klick feuert, Play/Pause '
                      'löst die Waffe oder das oberste Inventarfeld aus.',
                  'Controller: the left stick drives, the right stick aims, '
                      'R2 or A fires, L2 fires weapons such as grenade '
                      'launcher, mortar and drone. X, Y and the d-pad use the '
                      'inventory on the left edge. In defense, R1 builds a '
                      'turret and L1 switches the type. Siri Remote: your '
                      'thumb on the touch surface sets the direction, the '
                      'aim assist aims, a click fires, play/pause fires the '
                      'weapon or uses the top inventory slot.',
                )
              : touch
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
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(dialog).pop();
              game.showTutorial();
            },
            icon: const Icon(Icons.school, size: 18),
            label: Text(tr('EINWEISUNG ANSEHEN', 'VIEW BRIEFING')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('OK'),
          ),
        ],
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
    // Each column a group of its own: a remote walks down the left one
    // before it moves on to the right.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: FocusTraversalGroup(child: _column(left))),
        const SizedBox(width: 16),
        Expanded(child: FocusTraversalGroup(child: _column(right))),
      ],
    );
  }

  /// The settings of the round, opened by the host from the waiting room.
  Widget _settings(BuildContext context, {required bool narrow}) {
    final game = widget.game;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, tr('EINSTELLUNGEN', 'SETTINGS')),
        const SizedBox(height: 18),
        _columns(
          [_battleSection(context)],
          [_fieldSection(context)],
          narrow: narrow,
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: game.closeSettings,
              icon: const Icon(Icons.check),
              label: Text(tr('FERTIG', 'DONE')),
            ),
            OutlinedButton.icon(
              onPressed: game.changeMode,
              icon: const Icon(Icons.swap_horiz),
              label: Text(tr('MODUS WECHSELN', 'CHANGE MODE')),
            ),
          ],
        ),
      ],
    );
  }

  /// The waiting room: who is here, the player's own tank and the start.
  /// The host reaches the settings through the gear in the heading.
  Widget _room(BuildContext context, {required bool narrow}) {
    final host = widget.game.isHost.value;
    return ValueListenableBuilder<GameMode>(
      valueListenable: widget.game.mode,
      builder: (context, mode, _) {
        // Who is here and how to get others in. Alone, the tank is all.
        final room = [
          if (!host) const _JoinedBanner(),
          if (mode.withOthers) ...[
            if (host) RoomInvite(game: widget.game),
            _crewSection(),
          ],
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(
              context,
              mode.withOthers
                  ? tr('WARTERAUM', 'WAITING ROOM')
                  : tr('BEREITSTELLUNG', 'GET READY'),
              extra: [
                IconButton(
                  tooltip: tr('Steuerung', 'Controls'),
                  onPressed: () => _showControls(context),
                  icon: const Icon(Icons.help_outline),
                ),
                if (host)
                  IconButton(
                    tooltip: tr('Einstellungen', 'Settings'),
                    onPressed: widget.game.editSettings,
                    icon: const Icon(Icons.settings_outlined),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (mode.withOthers) ...[
              const ServerNotice(),
              ValueListenableBuilder(
                valueListenable: widget.game.roster,
                builder: (context, roster, _) => roster.length < 2
                    ? RoomsBusyNotice(slots: widget.game.slots, waiting: true)
                    : const SizedBox.shrink(),
              ),
            ],
            if (room.isEmpty)
              _tankSection(context)
            else
              _columns(room, [_tankSection(context)], narrow: narrow),
            const SizedBox(height: 18),
            _actions(),
          ],
        );
      },
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
  /// the screen edge already frames it. The television keeps it.
  bool _frameless(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600 ||
      (!kIsWeb &&
          !onTv &&
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
              // Phones and the tablet apps start at the top: short pages
              // leave the room below them instead of floating in the middle
              // of a screen held in the hand. The browser and the
              // television frame the menu as a plate, which sits best in
              // the middle.
              return Align(
                alignment: phone ? Alignment.topCenter : Alignment.center,
                child: FitOrScroll(
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
                    // The television is wide: two columns where a browser
                    // stacks, so the pages need no scrolling there.
                    constraints: BoxConstraints(maxWidth: onTv ? 1320 : 1040),
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
