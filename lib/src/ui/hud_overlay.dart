import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../app/env.dart';
import '../game/components/storm_zone.dart';
import '../net/pad_link.dart';
import '../net/payloads/defense_payload.dart';
import '../game/defense/tower.dart';
import '../game/special_weapon.dart';
import '../game/upgrades.dart';
import '../game/tank_game.dart';
import '../game/game_config.dart';
import 'theme.dart';
import 'widgets/ammo_gauge.dart';
import 'widgets/enemy_indicators.dart';
import 'widgets/health_bar.dart';
import 'widgets/inventory_bar.dart';
import 'widgets/kill_feed_view.dart';
import 'widgets/leave_round.dart';
import 'widgets/mini_map.dart';
import 'widgets/mute_button.dart';
import 'widgets/panel.dart';
import 'widgets/touch_controls.dart';
import 'widgets/vitals_plate.dart';
import '../l10n/l10n.dart';
import '../tv/tv_input.dart';
import '../tv/tv_menu_scope.dart';

class HudOverlay extends StatefulWidget {
  const HudOverlay({required this.game, super.key});

  final TankGame game;

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

/// Narrower than this the phone is held upright and the HUD stacks down the
/// left side instead of spreading along the top.
const _uprightWidth = 560.0;

/// Height of one gauge plate (armour, ammo, fuel) with the gap under it and a
/// little to spare; about 60 px on screen.
const _plateHeight = 62.0;

/// The inventory column on a keyboard screen: six 56 px slots with 2 px above
/// and below each.
const _inventoryHeight = GameConfig.inventorySlots * 60.0;

/// How far the gauges step in when they would reach down into the inventory:
/// its 8 px margin, a 56 px slot and a gap.
const _inventoryInset = 8 + 56 + 8.0;

/// How high the defense build panel reaches up from the bottom on a
/// keyboard screen, with a little air above it.
const _defensePanelReach = 250.0;

class _HudOverlayState extends State<HudOverlay> {
  Timer? _timer;

  // The plates the arrows to enemies off screen keep clear of.
  final _gaugesKey = GlobalKey();
  final _statusKey = GlobalKey();
  final _mapKey = GlobalKey();
  final _defenseKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _zoneLabel({bool compact = false}) {
    final round = widget.game.round;
    if (round == null) {
      return '';
    }
    if (round.defense) {
      return _waveLabel(compact: compact);
    }
    if (round.flag) {
      return _flagLabel(compact: compact);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final graceEndsAt =
        round.startedAt + GameConfig.zoneGraceSeconds.toInt() * 1000;
    if (now < graceEndsAt) {
      final seconds = ((graceEndsAt - now) / 1000).ceil();
      return compact
          ? tr('Sperrgebiet in $seconds s', 'Closed zone in $seconds s')
          : tr(
              'Sperrgebiet wird in $seconds s zugezogen',
              'Closed zone shrinks in $seconds s',
            );
    }
    final radius = StormZone.radiusAt(round.startedAt, now);
    final finalAt = round.startedAt + StormZone.finalAfter.toInt() * 1000;
    if (now >= finalAt) {
      return compact
          ? tr('Sperrgebiet schließt ganz', 'Zone closing in')
          : tr(
              'Sperrgebiet zieht sich ganz zu',
              'Closed zone draws in to nothing',
            );
    }
    if (radius <= GameConfig.zoneMinRadius) {
      final seconds = ((finalAt - now) / 1000).ceil();
      return compact
          ? tr('Sperrgebiet zu · $seconds s', 'Zone closed · $seconds s')
          : tr(
              'Sperrgebiet zu, in $seconds s zieht es sich ganz zu',
              'Closed zone shut, it draws in fully in $seconds s',
            );
    }
    // In metres like the arrows at the edge: the bare world units read
    // "Radius 844" next to an enemy "85 m" away.
    final metres = indicatorMetres(radius);
    return compact
        ? tr('Sicher: Radius $metres m', 'Safe: radius $metres m')
        : tr(
            'Sperrgebiet zieht sich zu: sicherer Radius $metres m',
            'Closed zone is shrinking: safe radius $metres m',
          );
  }

  /// The clock of a capture the flag round and what the player should do,
  /// in place of the closing zone.
  String _flagLabel({bool compact = false}) {
    final game = widget.game;
    final round = game.round;
    final match = game.flagMatch;
    if (round == null || match == null) {
      return '';
    }
    final elapsed =
        (DateTime.now().millisecondsSinceEpoch - round.startedAt) / 1000;
    final clock = match.overtime(elapsed)
        ? tr('VERLÄNGERUNG', 'OVERTIME')
        : () {
            final left = (GameConfig.flagRoundSeconds - max(0, elapsed))
                .ceil()
                .clamp(0, 9999);
            return '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
          }();
    if (compact) {
      return clock;
    }
    final mine = match.flags[game.myTeam];
    final String task;
    if (match.carriedBy(game.myId) != null) {
      task = tr('Bring die Fahne heim!', 'Bring the flag home!');
    } else if (mine != null && !mine.home) {
      task = tr('Hol eure Fahne zurück!', 'Get your flag back!');
    } else {
      task = tr('Hol die Fahne der anderen', 'Steal the other side\'s flag');
    }
    return '$clock · $task';
  }

  /// What the waves are up to, in place of the closing zone.
  String _waveLabel({bool compact = false}) {
    final state = widget.game.defense.value;
    if (state == null) {
      return '';
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (state.nextWaveAt > 0) {
      final seconds = ((state.nextWaveAt - now) / 1000).ceil().clamp(0, 999);
      if (state.deciding) {
        return compact
            ? tr('Gewonnen! Ende in $seconds s', 'Victory! End in $seconds s')
            : tr(
                'Gewonnen: Ende in $seconds s',
                'Victory secured: end in $seconds s',
              );
      }
      return compact
          ? tr(
              'Welle ${state.wave + 1} in $seconds s',
              'Wave ${state.wave + 1} in $seconds s',
            )
          : tr('Nächste Welle in $seconds s', 'Next wave in $seconds s');
    }
    return compact
        ? tr('Welle läuft', 'Wave on')
        : tr('Welle läuft: Haltet die Straße', 'Wave on: hold the road');
  }

  /// The wave out of the stretch under way: the regular ones or the
  /// extension's. [short] drops the word for windows too narrow for the
  /// whole line.
  static String _wave(DefensePayload? state, {bool short = false}) {
    final wave = state?.wave ?? 0;
    final last = state == null ? GameConfig.defenseWaves : state.lastWave;
    final extended = state != null && state.extended;
    if (last == null) {
      // A duel past the regular waves, or an older host's endless extension.
      return short
          ? tr('$wave · VERL.', '$wave · EXT.')
          : tr('WELLE $wave · VERLÄNGERUNG', 'WAVE $wave · EXTENSION');
    }
    if (short) {
      return '$wave/$last';
    }
    return extended
        ? tr('WELLE $wave/$last · VERL.', 'WAVE $wave/$last · EXT.')
        : tr('WELLE $wave/$last', 'WAVE $wave/$last');
  }

  /// Wave, enemies and comrades in one short line, for the phone panel.
  String _waveCounts() {
    final game = widget.game;
    final round = game.round;
    final allies = round == null ? 0 : round.alive.where(round.isAlly).length;
    // Without the word for the extension, which made the line too long for
    // an upright phone: the count up to its end says enough.
    final state = game.defense.value;
    final wave = state?.lastWave == null
        ? _wave(state)
        : '${tr('WELLE', 'WAVE')} ${_wave(state, short: true)}';
    return '$wave'
        ' · ${tr('FEINDE', 'ENEMIES')} ${game.enemiesOnField}'
        ' · ${tr('KAM.', 'ALLIES')} $allies';
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return ListenableBuilder(
      listenable: Listenable.merge([game.touchMode, game.compactHud]),
      builder: (context, _) => _layers(game),
    );
  }

  Widget _layers(TankGame game) {
    final touch = game.touchMode.value;
    return Stack(
      children: [
        if (touch || game.compactHud.value) _compact(game) else _status(game),
        _effects(game),
        EnemyIndicators(
          game: game,
          keepOut: [_gaugesKey, _statusKey, _mapKey, _defenseKey],
        ),
        // A paired phone or a controller brings its own sticks.
        if (touch)
          ListenableBuilder(
            listenable: Listenable.merge([
              PadScreen.instance.paired,
              TvInput.instance.count,
              game.touchOverPad,
            ]),
            builder: (context, _) =>
                PadScreen.instance.paired.value != null || steeredByPad(game)
                ? const SizedBox.shrink()
                : TouchControls(
                    input: game.touch,
                    special: game.specialNotifier,
                    onLook: game.lookAt,
                  ),
          ),
        LayoutBuilder(
          builder: (context, constraints) => SafeArea(
            minimum: const EdgeInsets.all(8),
            child: Align(
              alignment: Alignment(
                -1,
                _inventoryAlign(game, touch, constraints.maxHeight),
              ),
              child: _HudButtons(
                game: game,
                child: steeredByPad(game)
                    ? ValueListenableBuilder<TvPadKind>(
                        valueListenable: TvInput.instance.kind,
                        builder: (context, kind, _) => InventoryBar(
                          inventory: game.inventory,
                          onUse: game.useItem,
                          labels: kind == TvPadKind.remote
                              ? const ['⏯']
                              : (game.round?.duel ?? false)
                              ? tvDuelSlotLabels
                              : tvGamepadSlotLabels,
                        ),
                      )
                    : InventoryBar(
                        inventory: game.inventory,
                        onUse: game.useItem,
                        compact: touch,
                      ),
              ),
            ),
          ),
        ),
        if (game.round?.defense ?? false)
          _DefensePanel(
            plateKey: _defenseKey,
            game: game,
            touch: touch,
            counts: touch ? _waveCounts() : '',
            waveLabel: touch ? _waveLabel(compact: true) : '',
          )
        else if (onTv)
          _TvRoundMenu(game: game),
        TvMenuScope(
          open: game.leaveAsked,
          child: LeaveRoundPrompt(game: game),
        ),
      ],
    );
  }

  /// The situation in the top right corner: tanks left, the score or the
  /// wave, in mono like every value of the HUD.
  Widget _alive(TankGame game, TextStyle style) {
    return ValueListenableBuilder<int>(
      valueListenable: game.aliveCount,
      builder: (context, alive, _) {
        final round = game.round;
        if (round != null && round.defense) {
          final enemies = game.enemiesOnField;
          final allies = round.alive.where(round.isAlly).length;
          // The plate shares its row with the buttons; when the whole line
          // does not fit, the wave goes without its word first and then the
          // comrades are shortened as on the phone.
          List<String> lines(DefensePayload? state) => [
            for (final short in const [false, true])
              '${_wave(state, short: short)}   '
                  '${tr('FEINDE', 'ENEMIES')} $enemies   '
                  '${tr('KAMERADEN', 'COMRADES')} $allies',
            '${_wave(state, short: true)}   '
                '${tr('FEINDE', 'ENEMIES')} $enemies   '
                '${tr('KAM.', 'ALLIES')} $allies',
          ];
          return ValueListenableBuilder<DefensePayload?>(
            valueListenable: game.defense,
            builder: (context, state, _) => LayoutBuilder(
              builder: (context, constraints) {
                final candidates = lines(state);
                final painter = TextPainter(
                  textDirection: TextDirection.ltr,
                  textScaler: MediaQuery.textScalerOf(context),
                  maxLines: 1,
                );
                final merged = DefaultTextStyle.of(context).style.merge(style);
                final text = candidates.firstWhere((line) {
                  painter
                    ..text = TextSpan(text: line, style: merged)
                    ..layout();
                  return painter.width <= constraints.maxWidth;
                }, orElse: () => candidates.last);
                painter.dispose();
                return Text(text, style: style);
              },
            ),
          );
        }
        final match = game.flagMatch;
        if (round != null && round.flag && match != null) {
          return Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${tr('ROT', 'RED')} ${match.score[1]}',
                  style: TextStyle(color: GameConfig.teamColors[1]),
                ),
                const TextSpan(text: ' : '),
                TextSpan(
                  text: '${match.score[2]} ${tr('BLAU', 'BLUE')}',
                  style: TextStyle(color: GameConfig.teamColors[2]),
                ),
                TextSpan(
                  text: '  ${tr('BIS', 'TO')} ${GameConfig.flagCaptures}',
                  style: const TextStyle(color: GameColors.textMuted),
                ),
              ],
            ),
            style: style,
          );
        }
        if (round != null && round.teamMode) {
          return Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${tr('ROT', 'RED')} ${round.aliveIn(1)}',
                  style: TextStyle(color: GameConfig.teamColors[1]),
                ),
                const TextSpan(text: '   '),
                TextSpan(
                  text: '${tr('BLAU', 'BLUE')} ${round.aliveIn(2)}',
                  style: TextStyle(color: GameConfig.teamColors[2]),
                ),
              ],
            ),
            style: style,
          );
        }
        return Text(
          tr('$alive PANZER IM FELD', '$alive TANKS IN THE FIELD'),
          style: style,
        );
      },
    );
  }

  /// Phones held sideways: the thumbs own the lower corners and the lower half
  /// of the screen, so everything sits along the top in small plates.
  Widget _compact(TankGame game) {
    return SafeArea(
      minimum: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Upright phones lack the width for three plates in a row, so the
          // map moves under the gauges on the left.
          final upright = constraints.maxWidth < _uprightWidth;
          final map = MiniMap(
            key: _mapKey,
            game: game,
            size: upright ? 104 : 112,
          );
          return Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IgnorePointer(
                      key: _gaugesKey,
                      child: ListenableBuilder(
                        listenable: Listenable.merge([
                          game.hpNotifier,
                          game.ammoNotifier,
                          game.fuelNotifier,
                        ]),
                        builder: (context, _) => VitalsPlate(
                          hp: game.hpNotifier.value,
                          maxHp: game.myMaxHp,
                          ammo: game.ammoNotifier.value,
                          maxAmmo: game.myMagazine,
                          endless: game.endlessAmmo,
                          fuel: game.usesFuel ? game.fuelNotifier.value : null,
                        ),
                      ),
                    ),
                    if (upright) ...[
                      const SizedBox(height: HzSpace.s8),
                      IgnorePointer(child: map),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const MuteButton(),
                          LeaveRoundButton(game: game),
                        ],
                      ),
                    ],
                    IgnorePointer(
                      child: KillFeedView(feed: game.killFeed, compact: true),
                    ),
                  ],
                ),
              ),
              if (!upright) Align(alignment: Alignment.topCenter, child: map),
              Align(
                alignment: Alignment.topRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A defense round shows the waves in its own panel.
                    if (!(game.round?.defense ?? false))
                      IgnorePointer(
                        key: _statusKey,
                        child: Panel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: HzSpace.s8,
                            vertical: HzSpace.s4,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _alive(
                                game,
                                GameType.kennung.copyWith(
                                  color: GameColors.text,
                                ),
                              ),
                              const SizedBox(height: HzSpace.s2),
                              Text(
                                _zoneLabel(compact: true),
                                style: GameType.caption,
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!upright) ...[
                      const MuteButton(),
                      LeaveRoundButton(game: game),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Shells, and below them the fuel from the middle level on. The easy
  /// level hides the fuel and never runs out of shells, so it shows
  /// neither: an endless gauge would only take room.
  Widget _ammo(TankGame game) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!game.endlessAmmo)
          ValueListenableBuilder<int>(
            valueListenable: game.ammoNotifier,
            builder: (context, ammo, _) =>
                AmmoGauge(ammo: ammo, maxAmmo: game.myMagazine, endless: false),
          ),
        if (game.usesFuel) ...[
          if (!game.endlessAmmo) const SizedBox(height: HzSpace.s8),
          ValueListenableBuilder<double>(
            valueListenable: game.fuelNotifier,
            builder: (context, fuel, _) => FuelGauge(fuel: fuel),
          ),
        ],
      ],
    );
  }

  Widget _effects(TankGame game) {
    // On a desktop the defense panel fills the lower left and hid the wave
    // announcements, so there they show above the middle. On phones they
    // sit just under the tank: lower down they ran into the sticks, their
    // labels and the aim assist hint.
    final touch = game.touchMode.value;
    final high = (game.round?.defense ?? false) && !touch;
    return IgnorePointer(
      child: Align(
        alignment: high
            ? const Alignment(0, -0.35)
            : touch
            ? const Alignment(0, 0.3)
            : const Alignment(0, 0.55),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<String?>(
                valueListenable: game.notice,
                // On a plate rather than with a shadow, so it reads on any
                // ground; in capitals as an announcement.
                builder: (context, text, _) => text == null
                    ? const SizedBox()
                    : Panel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: HzSpace.s16,
                          vertical: HzSpace.s8,
                        ),
                        child: Text(
                          text.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: touch ? GameType.title : GameType.headline,
                        ),
                      ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: game.respawnSeconds,
                builder: (context, seconds, _) => seconds <= 0
                    ? const SizedBox()
                    : Padding(
                        padding: const EdgeInsets.only(top: HzSpace.s8),
                        // Two lines: in one the countdown broke off mid-word
                        // on an upright phone.
                        child: Panel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: HzSpace.s16,
                            vertical: HzSpace.s8,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    HorizontStatus.critical.icon,
                                    size: HzIconSize.row,
                                    color: GameColors.critical,
                                  ),
                                  const SizedBox(width: HzSpace.s8),
                                  Text(
                                    tr('ZERSTÖRT', 'DESTROYED'),
                                    style: GameType.title.copyWith(
                                      color: GameColors.critical,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                tr(
                                  'Einsatzbereit in $seconds s',
                                  'Ready in $seconds s',
                                ),
                                textAlign: TextAlign.center,
                                style: GameType.callout,
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: game.rapidFireSeconds,
                // A wrecked tank fires nothing, so its rapid fire stays out of
                // the way of the countdown.
                builder: (context, seconds, _) =>
                    seconds <= 0 || game.respawnSeconds.value > 0
                    ? const SizedBox()
                    : Padding(
                        padding: const EdgeInsets.only(top: HzSpace.s8),
                        child: Panel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: HzSpace.s12,
                            vertical: HzSpace.s8,
                          ),
                          child: Text(
                            tr(
                              'SCHNELLFEUER  $seconds s',
                              'RAPID FIRE  $seconds s',
                            ),
                            style: GameType.data,
                          ),
                        ),
                      ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: game.shieldSeconds,
                builder: (context, seconds, _) => seconds <= 0
                    ? const SizedBox()
                    : Padding(
                        padding: const EdgeInsets.only(top: HzSpace.s8),
                        child: Panel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: HzSpace.s12,
                            vertical: HzSpace.s8,
                          ),
                          child: Text(
                            tr('SCHILD  $seconds s', 'SHIELD  $seconds s'),
                            style: GameType.data,
                          ),
                        ),
                      ),
              ),
              // On phones the special weapon button shows the same.
              if (!game.touchMode.value)
                ValueListenableBuilder<(SpecialWeapon, int)?>(
                  valueListenable: game.specialNotifier,
                  builder: (context, special, _) => special == null
                      ? const SizedBox()
                      : Padding(
                          padding: const EdgeInsets.only(top: HzSpace.s8),
                          child: SpecialPlate(
                            weapon: special.$1,
                            charges: special.$2,
                            keyHint: 'F',
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Where the inventory sits on the left edge, as the y of an [Alignment]:
  /// a little below the middle, except in a defense round on a keyboard
  /// screen, where the build panel fills the lower left corner and five
  /// items ran under it. There the column goes up until its foot clears
  /// the panel, at most to the top.
  double _inventoryAlign(TankGame game, bool touch, double height) {
    const usual = 0.1;
    if (touch) {
      return 0.15;
    }
    if (!(game.round?.defense ?? false)) {
      return usual;
    }
    final room = height - 16 - _inventoryHeight;
    if (room <= 0) {
      return -1;
    }
    // The column's top lies at 8 + room * (y + 1) / 2; its foot has to
    // stay above the panel.
    final clear =
        2 * (height - _defensePanelReach - _inventoryHeight - 8) / room - 1;
    return clear.clamp(-1.0, usual);
  }

  /// Whether the gauges in the top left corner would reach down into the
  /// inventory, which sits vertically centred (a little low) on the left edge.
  /// Short windows such as a laptop browser bring it up under the gauges.
  bool _gaugesMeetInventory(TankGame game, double height) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final plates = 1 + (game.endlessAmmo ? 0 : 1) + (game.usesFuel ? 1 : 0);
    final gaugesBottom = 16 + plates * _plateHeight * scale;
    // Same placement as the Align inside the SafeArea in build().
    final align = _inventoryAlign(game, false, height);
    final inventoryTop = 8 + (height - 16 - _inventoryHeight) * (align + 1) / 2;
    return gaugesBottom + 8 > inventoryTop;
  }

  Widget _status(TankGame game) {
    return LayoutBuilder(
      builder: (context, constraints) => _statusColumn(
        game,
        _gaugesMeetInventory(game, constraints.maxHeight),
      ),
    );
  }

  Widget _statusColumn(TankGame game, bool inset) {
    return Padding(
      padding: EdgeInsets.fromLTRB(inset ? _inventoryInset : 16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IgnorePointer(
                key: _gaugesKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<double>(
                      valueListenable: game.hpNotifier,
                      builder: (context, hp, _) =>
                          HealthBar(hp: hp, maxHp: game.myMaxHp),
                    ),
                    if (!game.endlessAmmo || game.usesFuel)
                      const SizedBox(height: HzSpace.s8),
                    _ammo(game),
                  ],
                ),
              ),
              // The buttons sit in the row beside the plate, so a long wave
              // line pushes them aside instead of running underneath them,
              // and a narrow window wraps the plate rather than overflowing.
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HudButtons(
                      game: game,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const MuteButton(),
                          LeaveRoundButton(game: game),
                        ],
                      ),
                    ),
                    const SizedBox(width: HzSpace.s8),
                    Flexible(
                      child: IgnorePointer(
                        key: _statusKey,
                        child: Panel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: HzSpace.s12,
                            vertical: HzSpace.s8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _alive(
                                game,
                                GameType.data.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              ValueListenableBuilder<int>(
                                valueListenable: game.soldiersRunOver,
                                builder: (context, n, _) => n == 0
                                    ? const SizedBox()
                                    : Text(
                                        tr('ÜBERROLLT: $n', 'RUN OVER: $n'),
                                        style: GameType.data.copyWith(
                                          color: GameColors.critical,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: HzSpace.s4),
                              Text(
                                _zoneLabel(),
                                style: GameType.callout.copyWith(
                                  color: GameColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: HzSpace.s8),
          // Six kills in a short window would push the mini map off the
          // screen: the feed gets the room left, and the oldest lines at
          // its top give way first.
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: UnconstrainedBox(
                constrainedAxis: Axis.horizontal,
                alignment: Alignment.bottomLeft,
                clipBehavior: Clip.hardEdge,
                child: IgnorePointer(child: KillFeedView(feed: game.killFeed)),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: IgnorePointer(
              child: MiniMap(key: _mapKey, game: game),
            ),
          ),
        ],
      ),
    );
  }
}

/// Defense round: how the base stands, the money, the buttons that put a
/// gun where the tank stands or upgrade the one next to it, and the
/// upgrades for the tank.
class _DefensePanel extends StatefulWidget {
  const _DefensePanel({
    required this.plateKey,
    required this.game,
    required this.touch,
    required this.counts,
    required this.waveLabel,
  });

  /// Lets the arrows to enemies off screen keep clear of the panel.
  final GlobalKey plateKey;
  final TankGame game;
  final bool touch;

  /// Phones only: the wave line and the countdown, which there have no plate
  /// of their own.
  final String counts;
  final String waveLabel;

  @override
  State<_DefensePanel> createState() => _DefensePanelState();
}

/// What the touch panel shows below its header: nothing, the guns to build
/// or the upgrades for the tank. One list at a time keeps the arena visible.
enum _Shop { closed, towers, upgrades }

class _DefensePanelState extends State<_DefensePanel> {
  /// Widest the defense panel grows on a desktop.
  static const _deskPanelWidth = 540.0;

  /// The store picture of the defense shows the guns to build.
  _Shop _shop = Env.shotScene == 'defense' ? _Shop.towers : _Shop.closed;

  /// The list the desktop panel shows, the guns to begin with.
  _Shop _desk = _Shop.towers;

  TankGame get game => widget.game;
  bool get touch => widget.touch;

  ButtonStyle get _buttonStyle => ButtonStyle(
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(
        horizontal: touch ? HzSpace.s8 : HzSpace.s12,
        vertical: HzSpace.s4,
      ),
    ),
    // Big enough for a thumb on phones, still a single line of text.
    minimumSize: WidgetStatePropertyAll(Size(0, touch ? 32 : 30)),
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  /// The labels of the panel's buttons: small, without a colour of their
  /// own, so the button's foreground still says enabled or not.
  TextStyle get _small => TextStyle(
    fontSize: touch ? HzType.kennung.size : HzType.caption.size,
    fontWeight: FontWeight.w600,
  );

  /// What can be bought now is bright, ink in the outline on the sunken
  /// ground; what cannot is only a faint line, so the two never look alike.
  ButtonStyle get _buyStyle => _buttonStyle.copyWith(
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? Colors.transparent
          : GameColors.sunken,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? GameColors.textFaint
          : GameColors.text,
    ),
    side: WidgetStateProperty.resolveWith(
      (states) => BorderSide(
        color: states.contains(WidgetState.disabled)
            ? GameColors.line
            : GameColors.lineStrong,
      ),
    ),
  );

  /// An open list is the selection: the 2 px accent line on its tint,
  /// never the fill of the primary action.
  ButtonStyle _tabStyle(ButtonStyle base, {required bool open}) => open
      ? base.copyWith(
          backgroundColor: const WidgetStatePropertyAll(GameColors.accentTint),
          foregroundColor: const WidgetStatePropertyAll(GameColors.accentText),
          side: const WidgetStatePropertyAll(
            BorderSide(color: GameColors.accentText, width: HzLine.selection),
          ),
        )
      : base;

  Widget _nearTower(Tower near, int credits) {
    return FilledButton.icon(
      style: _buttonStyle,
      onPressed:
          near.kind.upgradable &&
              near.level < _towerLimit &&
              credits >= near.kind.upgradeCost(near.level)
          ? () => game.upgradeTower(near)
          : null,
      icon: const Icon(Icons.upgrade_outlined, size: HzIconSize.inline),
      label: Text(
        !near.kind.upgradable
            ? tr('${near.kind.label} BESETZT', '${near.kind.label} OCCUPIED')
            : near.level >= TowerKind.maxLevel
            ? tr(
                '${near.kind.label} HÖCHSTE STUFE',
                '${near.kind.label} MAXIMUM LEVEL',
              )
            : near.level >= _towerLimit
            ? tr(
                '${near.kind.label} STUFE ${near.level + 1} IN VERLÄNGERUNG',
                '${near.kind.label} LEVEL ${near.level + 1} IN EXTENSION',
              )
            : '${near.kind.label} ${tr('AUFRÜSTEN', 'UPGRADE')}  '
                  '${near.kind.upgradeCost(near.level)}',
        style: _small,
      ),
    );
  }

  int get _towerLimit => TowerKind.levelLimit(extended: game.extended);

  Widget _towers(int credits) {
    final wave = game.defense.value?.wave ?? 0;
    final extended = game.extended;
    return Wrap(
      spacing: HzSpace.s8,
      runSpacing: HzSpace.s4,
      children: [
        for (final kind in TowerKind.values)
          if (!kind.extension || extended)
            Tooltip(
              message: switch (kind.lockedIn(wave, extended: extended)) {
                final locked? => '${kind.hint}, $locked',
                null => kind.hint,
              },
              // Only bright or faint, never marked: the gun built last
              // stayed filled and read as picked, or as the one thing the
              // funds still reached. Which kind B builds the line above says.
              child: OutlinedButton(
                style: _buyStyle,
                onPressed:
                    credits >= game.buildCost(kind) &&
                        kind.unlockedIn(wave, extended: extended)
                    ? () => game.buildTower(kind)
                    : null,
                child: Text(
                  kind.unlockedIn(wave, extended: extended)
                      ? '${kind.label} ${game.buildCost(kind)}'
                      : '${kind.label} ${tr('AB W', 'FROM W')}${kind.fromWave}',
                  style: _small,
                ),
              ),
            ),
      ],
    );
  }

  Widget _upgrades(int credits) {
    return Wrap(
      spacing: HzSpace.s8,
      runSpacing: HzSpace.s4,
      children: [
        for (final kind in UpgradeKind.values) _upgrade(kind, credits),
      ],
    );
  }

  Widget _shopDesktop(int credits) {
    final near = game.nearTower.value;
    final bounty = GameConfig.bountyIn(
      GameConfig.creditsPerKill,
      max(1, game.defense.value?.wave ?? 1),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${tr('MÜNZEN', 'COINS')} $credits   ·   ${_buildKeys(game)}'
          '${(game.round?.duel ?? false) ? tr('   ·   ${steeredByPad(game) ? 'Y' : 'T'} schickt Panzer ${GameConfig.troopCost}', '   ·   ${steeredByPad(game) ? 'Y' : 'T'} sends a tank ${GameConfig.troopCost}') : ''}',
          style: GameType.label.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          tr(
            'Münzen gibt es für eigene Abschüsse (Panzer jetzt +$bounty, mit '
                'jeder Welle weniger) und jede abgewehrte Welle '
                '(+${GameConfig.waveBonus}).',
            'Coins come with your own kills (a tank now +$bounty, less '
                'with every wave) and every wave beaten off '
                '(+${GameConfig.waveBonus}).',
          ),
          style: GameType.caption,
        ),
        const SizedBox(height: HzSpace.s8),
        // One list at a time, like on phones: with both the panel covered a
        // quarter of a laptop screen and the road beneath it. A narrow
        // window wraps the call for the next wave below the tabs.
        Wrap(
          spacing: HzSpace.s8,
          runSpacing: HzSpace.s4,
          children: [
            _deskTab(tr('GESCHÜTZE', 'GUNS'), _Shop.towers),
            _deskTab(tr('AUFRÜSTUNG', 'UPGRADES'), _Shop.upgrades),
            if (game.canCallWave) _callWave(),
          ],
        ),
        const SizedBox(height: HzSpace.s8),
        if (_desk == _Shop.upgrades)
          _upgrades(credits)
        else if (near != null)
          _nearTower(near, credits)
        else
          _towers(credits),
      ],
    );
  }

  Widget _deskTab(String label, _Shop shop) {
    final open = _desk == shop;
    return _ready(
      shop,
      OutlinedButton(
        style: _tabStyle(_buttonStyle, open: open),
        onPressed: () => setState(() => _desk = shop),
        child: Text(label, style: _small),
      ),
    );
  }

  /// Whether the funds reach for something behind the list [shop].
  bool _affordable(_Shop shop) => switch (shop) {
    _Shop.towers => game.anyTowerAffordable,
    _Shop.upgrades => game.anyUpgradeAffordable,
    _Shop.closed => false,
  };

  /// A dot on the corner of the button for [shop] while the funds reach for
  /// something behind it, so a closed list still says when to look. In the
  /// positive colour: the accent belongs to the selection.
  Widget _ready(_Shop shop, Widget button) => Badge(
    isLabelVisible: _affordable(shop),
    smallSize: HzSpace.s8,
    backgroundColor: GameColors.positive,
    offset: const Offset(-2, 2),
    child: button,
  );

  /// The host skips the rest of the break. Outlined: building and
  /// upgrading are the panel's main actions.
  Widget _callWave() {
    return OutlinedButton.icon(
      style: _buttonStyle,
      onPressed: game.callWaveNow,
      icon: const Icon(Icons.fast_forward_outlined, size: HzIconSize.inline),
      label: Text(
        touch || steeredByPad(game)
            ? tr('WELLE JETZT', 'WAVE NOW')
            : tr('WELLE JETZT (N)', 'WAVE NOW (N)'),
        style: _small,
      ),
    );
  }

  /// A list toggle of the phone panel: only the symbol, the name is in the
  /// tooltip and for the screen reader. Spelled out, the two tabs and the
  /// funds took a line of their own on an upright phone.
  Widget _tab(String label, IconData icon, _Shop shop) {
    final open = _shop == shop;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: open,
        label: label,
        value: _affordable(shop) ? tr('Münzen reichen', 'Enough coins') : null,
        child: ExcludeSemantics(
          child: _ready(
            shop,
            OutlinedButton(
              style: _tabStyle(_iconStyle, open: open),
              onPressed: () =>
                  setState(() => _shop = open ? _Shop.closed : shop),
              child: Icon(icon, size: HzIconSize.row),
            ),
          ),
        ),
      ),
    );
  }

  ButtonStyle get _iconStyle => _buttonStyle.copyWith(
    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
    minimumSize: const WidgetStatePropertyAll(Size(40, 32)),
  );

  /// Phones: one line with the funds and the toggles, the lists fold out on
  /// demand. Standing by a gun shows its upgrade button right away.
  Widget _shopTouch(int credits) {
    final near = game.nearTower.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$credits',
              semanticsLabel: tr('Münzen $credits', 'Coins $credits'),
              style: GameType.data.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: HzSpace.s2),
            const Icon(
              Icons.paid_outlined,
              size: HzIconSize.badge,
              color: GameColors.textMuted,
            ),
            const SizedBox(width: HzSpace.s8),
            _tab(
              tr('Geschütze', 'Guns'),
              Icons.construction_outlined,
              _Shop.towers,
            ),
            const SizedBox(width: HzSpace.s4),
            _tab(
              tr('Aufrüstung', 'Upgrades'),
              Icons.upgrade_outlined,
              _Shop.upgrades,
            ),
            if (game.canCallWave) ...[
              const SizedBox(width: HzSpace.s4),
              Tooltip(
                message: tr('Welle jetzt', 'Wave now'),
                child: Semantics(
                  button: true,
                  label: tr('Welle jetzt', 'Wave now'),
                  child: ExcludeSemantics(
                    child: OutlinedButton(
                      style: _iconStyle,
                      onPressed: game.callWaveNow,
                      child: const Icon(
                        Icons.fast_forward_outlined,
                        size: HzIconSize.row,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (near != null) ...[
          const SizedBox(height: HzSpace.s4),
          _nearTower(near, credits),
        ],
        if (_shop != _Shop.closed) ...[
          const SizedBox(height: HzSpace.s4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330),
            child: _shop == _Shop.towers
                ? _towers(credits)
                : _upgrades(credits),
          ),
        ],
      ],
    );
  }

  Widget _upgrade(UpgradeKind kind, int credits) {
    final level = game.upgrades.value[kind] ?? 0;
    final limit = GameConfig.upgradeLimit(extended: game.extended);
    final maxed = level >= limit;
    final cost = kind.costFrom(level);
    return Tooltip(
      message: '${kind.label}: ${kind.effect} ${tr('je Stufe', 'per level')}',
      child: OutlinedButton(
        style: _buyStyle.copyWith(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: HzSpace.s8, vertical: HzSpace.s2),
          ),
          minimumSize: WidgetStatePropertyAll(Size(0, touch ? 32 : 28)),
        ),
        onPressed: !maxed && credits >= cost
            ? () => game.buyUpgrade(kind)
            : null,
        child: Text(
          '${kind.label} ${'●' * level}${'○' * (limit - level)}'
          '${maxed ? '' : ' $cost'}',
          style: _small,
        ),
      ),
    );
  }

  /// After the last wave of a stretch: the host extends or ends the round,
  /// everybody else learns what is at stake. Ending later goes through the
  /// exit button, whose question offers the win.
  Widget _decision() {
    return ValueListenableBuilder<DefensePayload?>(
      valueListenable: game.defense,
      builder: (context, state, _) {
        if (state == null || !state.deciding) {
          return const SizedBox.shrink();
        }
        final host = game.round?.botHost == game.myId;
        const more = GameConfig.defenseExtension;
        final first = !state.extended;
        final small = GameType.caption.copyWith(color: GameColors.text);
        final align = touch ? TextAlign.end : TextAlign.start;
        return Padding(
          padding: EdgeInsets.only(bottom: touch ? HzSpace.s8 : HzSpace.s12),
          child: Column(
            crossAxisAlignment: touch
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Won: the positive sign and colour with the word.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    HorizontStatus.positive.icon,
                    size: HzIconSize.inline,
                    color: GameColors.positive,
                  ),
                  const SizedBox(width: HzSpace.s4),
                  Flexible(
                    child: Text(
                      tr(
                        'WELLE ${state.wave} GEHALTEN · GEWONNEN',
                        'WAVE ${state.wave} HELD · VICTORY SECURED',
                      ),
                      textAlign: align,
                      style: GameType.label.copyWith(
                        color: GameColors.positive,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: HzSpace.s2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  !state.canExtend
                      ? tr(
                          'Das war die letzte Welle.',
                          'That was the last wave.',
                        )
                      : first
                      ? tr(
                          'Noch $more Wellen: zähere Gegner, Stufe 4 und 5, '
                              'Raketenwerfer. Gewonnen bleibt gewonnen.',
                          '$more more waves: tougher enemies, levels 4 and 5, '
                              'rocket launchers. The victory stays.',
                        )
                      : tr(
                          'Noch $more Wellen, noch zäher. Gewonnen bleibt gewonnen.',
                          '$more more waves, tougher still. The victory stays.',
                        ),
                  textAlign: align,
                  style: small,
                ),
              ),
              const SizedBox(height: HzSpace.s4),
              // One row, as asked in the play test: the two choices side by
              // side, shrinking rather than wrapping on a narrow phone.
              if (host)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: touch
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.canExtend) ...[
                        FilledButton.icon(
                          style: _buttonStyle,
                          onPressed: game.extendDefense,
                          icon: const Icon(
                            Icons.add_outlined,
                            size: HzIconSize.inline,
                          ),
                          label: Text(
                            tr('$more WELLEN', '$more WAVES'),
                            style: _small,
                          ),
                        ),
                        const SizedBox(width: HzSpace.s8),
                      ],
                      OutlinedButton.icon(
                        style: _buyStyle,
                        onPressed: game.withdrawDefense,
                        icon: const Icon(
                          Icons.flag_outlined,
                          size: HzIconSize.inline,
                        ),
                        label: Text(tr('BEENDEN', 'END'), style: _small),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  tr(
                    'Der Gastgeber entscheidet, ob es weitergeht.',
                    'The host decides whether it goes on.',
                  ),
                  textAlign: align,
                  style: small.copyWith(color: GameColors.textMuted),
                ),
            ],
          ),
        );
      },
    );
  }

  /// The other side's base in a duel: how far it is from falling.
  Widget _rivalBase(DefensePayload state, int lane) {
    final hp = state.hpOf(lane);
    final ratio = (hp / GameConfig.baseMaxHp(state.hqOf(lane))).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${tr('GEGNER', 'RIVAL')} · ${GameConfig.hqName(state.hqOf(lane))}'
          '  ${hp.ceil()}',
          style: GameType.kennung.copyWith(
            color: GameConfig.teamColors[lane + 1],
          ),
        ),
        const SizedBox(height: HzSpace.s4),
        // The other side in its team colour, which names it in the world.
        SizedBox(
          width: 200,
          child: GaugeBar(value: ratio, color: GameConfig.teamColors[lane + 1]),
        ),
      ],
    );
  }

  Widget _base() {
    return ValueListenableBuilder<DefensePayload?>(
      valueListenable: game.defense,
      builder: (context, state, _) {
        // In a duel the own base, and below it the other side's.
        final lane = game.myLane;
        final hq = state?.hqOf(lane) ?? 1;
        final hp = state?.hpOf(lane) ?? GameConfig.baseHp;
        final ratio = (hp / GameConfig.baseMaxHp(hq)).clamp(0.0, 1.0);
        // The base like the armour: ink, then warning and critical, with
        // the sign beside the value.
        final status = armourStatus(ratio);
        final bar = SizedBox(
          width: touch ? 72 : 200,
          child: GaugeBar(
            value: ratio,
            status: status,
            height: touch ? HzSpace.s4 : HzSpace.s8,
          ),
        );
        // The text wraps in a narrow window, the sign stays beside it.
        final label = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                touch
                    ? '${hp.ceil()}'
                    : '${tr('STÜTZPUNKT', 'BASE')} · ${GameConfig.hqName(hq)}  ${hp.ceil()}',
                style: GameType.kennung.copyWith(color: stockColor(status)),
              ),
            ),
            StockSign(status, size: HzIconSize.badge),
          ],
        );
        if (touch) {
          // Upright the wave label may have to drop below the bar.
          return Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 2,
            children: [
              Tooltip(
                message:
                    '${tr('Stützpunkt', 'Base')} · ${GameConfig.hqName(hq)}',
                child: const Icon(
                  Icons.flag_outlined,
                  size: HzIconSize.badge,
                  color: GameColors.textMuted,
                ),
              ),
              const SizedBox(width: HzSpace.s4),
              bar,
              const SizedBox(width: HzSpace.s8),
              label,
              const SizedBox(width: HzSpace.s12),
              Text(widget.waveLabel, style: GameType.caption),
            ],
          );
        }
        final rival = state != null && state.duel ? 1 - lane : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            label,
            const SizedBox(height: HzSpace.s4),
            bar,
            if (rival != null) ...[
              const SizedBox(height: HzSpace.s8),
              _rivalBase(state!, rival),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final panel = Panel(
      padding: touch
          ? const EdgeInsets.symmetric(
              horizontal: HzSpace.s8,
              vertical: HzSpace.s8,
            )
          : const EdgeInsets.symmetric(
              horizontal: HzSpace.s12,
              vertical: HzSpace.s8,
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: touch
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (touch) ...[
            Text(
              widget.counts,
              textAlign: TextAlign.end,
              style: GameType.kennung.copyWith(color: GameColors.text),
            ),
            const SizedBox(height: HzSpace.s4),
          ],
          if (onTv)
            ValueListenableBuilder<bool>(
              valueListenable: game.tvMenu,
              builder: (context, open, _) => open
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: HzSpace.s8),
                      child: _TvMenuButtons(game: game),
                    )
                  : const SizedBox.shrink(),
            ),
          _decision(),
          _base(),
          SizedBox(height: touch ? HzSpace.s4 : HzSpace.s8),
          ListenableBuilder(
            listenable: Listenable.merge([
              game.credits,
              game.towerChoice,
              game.nearTower,
              game.upgrades,
              game.defense,
            ]),
            builder: (context, _) => touch
                ? _shopTouch(game.credits.value)
                : _shopDesktop(game.credits.value),
          ),
        ],
      ),
    );
    return SafeArea(
      minimum: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: touch ? Alignment.topRight : Alignment.bottomLeft,
          child: Padding(
            // Phones: in the top right corner.
            // Room for the exit and the mute button, which only the browser
            // shows. Upright both sit under the gauges.
            padding: touch
                ? EdgeInsets.only(
                    right: MediaQuery.sizeOf(context).width < _uprightWidth
                        ? 0
                        : onTv
                        ? 0
                        : (kIsWeb ? 96 : 48),
                  )
                // Desktops: clear of the mini map in the lower right, so a
                // narrow window wraps the buttons instead of covering it.
                : const EdgeInsets.fromLTRB(8, 8, MiniMap.defaultSize + 24, 8),
            child: _HudButtons(
              game: game,
              // Upright phones: the gauges, the map and the kill feed fill the
              // left column, so the panel keeps to the width beside it and
              // wraps instead of covering them.
              child: touch && constraints.maxWidth < _uprightWidth
                  ? ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: max(
                          0,
                          constraints.maxWidth - VitalsPlate.outerWidth - 6,
                        ),
                      ),
                      child: KeyedSubtree(key: widget.plateKey, child: panel),
                    )
                  : touch
                  ? KeyedSubtree(key: widget.plateKey, child: panel)
                  // The money line, the note and the guns wrap instead of
                  // stretching the panel: it once took two thirds of a
                  // laptop screen.
                  : ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _deskPanelWidth,
                      ),
                      child: KeyedSubtree(
                        key: widget.plateKey,
                        child: TvMenuScope(open: game.tvMenu, child: panel),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The way back to the tank and out of the round, at the top of the round
/// menu of a television.
class _TvMenuButtons extends StatelessWidget {
  const _TvMenuButtons({required this.game});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tr(
            'MENÜ · Wischen wählt, Klick oder Play/Pause löst aus, Menü schließt',
            'MENU · swipe to choose, click or play/pause to press, Menu closes',
          ),
          style: GameType.kennung,
        ),
        const SizedBox(height: HzSpace.s8),
        Wrap(
          spacing: HzSpace.s8,
          runSpacing: HzSpace.s4,
          children: [
            FilledButton.icon(
              onPressed: () => game.tvMenu.value = false,
              icon: const Icon(
                Icons.play_arrow_outlined,
                size: HzIconSize.inline,
              ),
              label: Text(tr('WEITERSPIELEN', 'KEEP PLAYING')),
            ),
            OutlinedButton.icon(
              onPressed: () {
                game.tvMenu.value = false;
                game.leaveAsked.value = true;
              },
              icon: const Icon(Icons.logout_outlined, size: HzIconSize.inline),
              label: Text(tr('RUNDE VERLASSEN', 'LEAVE ROUND')),
            ),
          ],
        ),
      ],
    );
  }
}

/// The round menu of a television outside a defense round, where there is
/// nothing to build: back to the tank, or out of the round.
class _TvRoundMenu extends StatelessWidget {
  const _TvRoundMenu({required this.game});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: game.tvMenu,
      builder: (context, open, _) => open
          ? Center(
              child: TvMenuScope(
                open: game.tvMenu,
                child: Panel(
                  padding: const EdgeInsets.fromLTRB(
                    HzSpace.s24,
                    HzSpace.s16,
                    HzSpace.s24,
                    HzSpace.s16,
                  ),
                  child: _TvMenuButtons(game: game),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Marks the mouse as over HUD buttons while it is, so clicking them does not
/// also fire the gun.
class _HudButtons extends StatelessWidget {
  const _HudButtons({required this.game, required this.child});

  final TankGame game;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => game.pointerOnHud = true,
      onExit: (_) => game.pointerOnHud = false,
      child: child,
    );
  }
}

/// Which buttons build and switch guns, for what steers [game]: the remote
/// has only the one button, which builds the kind picked last.
String _buildKeys(TankGame game) {
  final choice = game.towerChoice.value.label;
  if (!steeredByPad(game)) {
    return tr(
      'B baut $choice/rüstet auf, V wechselt',
      'B builds $choice/upgrades, V switches',
    );
  }
  if (TvInput.instance.player(game.tvPlayer).kind == TvPadKind.remote ||
      (onTv && TvInput.instance.player(game.tvPlayer).kind == TvPadKind.none)) {
    return onAppleTv
        ? tr(
            'Play/Pause baut $choice/rüstet auf · Menü: Auswahl, Verlassen',
            'play/pause builds $choice/upgrades · Menu: choose, leave',
          )
        : tr(
            'Play/Pause oder Menü baut $choice/rüstet auf',
            'play/pause or menu builds $choice/upgrades',
          );
  }
  return tr(
    'R1 baut $choice/rüstet auf, L1 wechselt',
    'R1 builds $choice/upgrades, L1 switches',
  );
}
