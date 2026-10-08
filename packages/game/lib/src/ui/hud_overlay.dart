import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/bot_level.dart';
import '../game/components/storm_zone.dart';
import '../net/payloads/defense_payload.dart';
import '../game/defense/tower.dart';
import '../game/special_weapon.dart';
import '../game/upgrades.dart';
import '../game/space_game.dart';
import '../game_config.dart';
import '../theme.dart';
import 'widgets/ammo_gauge.dart';
import 'widgets/enemy_indicators.dart';
import 'widgets/health_bar.dart';
import 'widgets/inventory_bar.dart';
import 'widgets/kill_feed_view.dart';
import 'widgets/mini_map.dart';
import 'widgets/mute_button.dart';
import 'widgets/panel.dart';
import 'widgets/touch_controls.dart';
import 'widgets/vitals_plate.dart';
import '../l10n/l10n.dart';

class HudOverlay extends StatefulWidget {
  const HudOverlay({required this.game, super.key});

  final SpaceGame game;

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

/// Narrower than this the phone is held upright and the HUD stacks down the
/// left side instead of spreading along the top.
const _uprightWidth = 560.0;

class _HudOverlayState extends State<HudOverlay> {
  Timer? _timer;

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
    if (radius <= GameConfig.zoneMinRadius) {
      return compact
          ? tr('Sperrgebiet zu', 'Zone closed')
          : tr(
              'Sperrgebiet vollständig geschlossen',
              'Closed zone fully shrunk',
            );
    }
    return compact
        ? tr(
            'Sicher: Radius ${radius.round()}',
            'Safe: radius ${radius.round()}',
          )
        : tr(
            'Sperrgebiet zieht sich zu: sicherer Radius ${radius.round()}',
            'Closed zone is shrinking: safe radius ${radius.round()}',
          );
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
            ? tr('Sieg! Ende in $seconds s', 'Victory! End in $seconds s')
            : tr(
                'Sieg gesichert: Ende in $seconds s',
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

  /// The wave out of the regular ones, or how far into the extension.
  static String _wave(DefensePayload? state) {
    final wave = state?.wave ?? 0;
    return state != null && state.extended
        ? tr('WELLE $wave · VERLÄNGERUNG', 'WAVE $wave · EXTENSION')
        : tr(
            'WELLE $wave/${GameConfig.defenseWaves}',
            'WAVE $wave/${GameConfig.defenseWaves}',
          );
  }

  /// Wave, enemies and comrades in one short line, for the phone panel.
  String _waveCounts() {
    final game = widget.game;
    final round = game.round;
    final allies = round == null ? 0 : round.alive.where(round.isAlly).length;
    return '${_wave(game.defense.value)}'
        ' · ${tr('FEINDE', 'ENEMIES')} ${game.enemiesOnField}'
        ' · ${tr('KAM.', 'ALLIES')} $allies';
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return ValueListenableBuilder<bool>(
      valueListenable: game.touchMode,
      builder: (context, touch, _) => Stack(
        children: [
          if (touch) _compact(game) else _status(game),
          _effects(game),
          if (!touch)
            const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 12),
                child: MuteButton(),
              ),
            ),
          EnemyIndicators(game: game),
          if (touch)
            TouchControls(
              input: game.touch,
              special: game.specialNotifier,
              assist: game.difficulty != BotLevel.hard,
            ),
          SafeArea(
            minimum: const EdgeInsets.all(8),
            child: Align(
              alignment: touch
                  ? const Alignment(-1, 0.15)
                  : const Alignment(-1, 0.1),
              child: _HudButtons(
                game: game,
                child: InventoryBar(
                  inventory: game.inventory,
                  onUse: game.useItem,
                  compact: touch,
                ),
              ),
            ),
          ),
          if (game.round?.defense ?? false)
            _DefensePanel(
              game: game,
              touch: touch,
              counts: touch ? _waveCounts() : '',
              waveLabel: touch ? _waveLabel(compact: true) : '',
            ),
        ],
      ),
    );
  }

  Widget _alive(SpaceGame game, double fontSize) {
    final style = TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800);
    return ValueListenableBuilder<int>(
      valueListenable: game.aliveCount,
      builder: (context, alive, _) {
        final round = game.round;
        if (round != null && round.defense) {
          final enemies = game.enemiesOnField;
          final allies = round.alive.where(round.isAlly).length;
          return ValueListenableBuilder<DefensePayload?>(
            valueListenable: game.defense,
            builder: (context, state, _) => Text(
              '${_wave(state)}   ${tr('FEINDE', 'ENEMIES')} $enemies   '
              '${tr('KAMERADEN', 'COMRADES')} $allies',
              style: style,
            ),
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
  Widget _compact(SpaceGame game) {
    return SafeArea(
      minimum: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Upright phones lack the width for three plates in a row, so the
          // map moves under the gauges on the left.
          final upright = constraints.maxWidth < _uprightWidth;
          final map = MiniMap(game: game, size: upright ? 104 : 112);
          return Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IgnorePointer(
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
                      const SizedBox(height: 6),
                      IgnorePointer(child: map),
                      const MuteButton(),
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
                        child: Panel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _alive(game, 11),
                              const SizedBox(height: 2),
                              Text(
                                _zoneLabel(compact: true),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: BwColors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!upright) const MuteButton(),
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
  /// level hides the fuel and never runs out of shells.
  Widget _ammo(SpaceGame game) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<int>(
          valueListenable: game.ammoNotifier,
          builder: (context, ammo, _) => AmmoGauge(
            ammo: ammo,
            maxAmmo: game.myMagazine,
            endless: game.endlessAmmo,
          ),
        ),
        if (game.usesFuel) ...[
          const SizedBox(height: 6),
          ValueListenableBuilder<double>(
            valueListenable: game.fuelNotifier,
            builder: (context, fuel, _) => FuelGauge(fuel: fuel),
          ),
        ],
      ],
    );
  }

  Widget _effects(SpaceGame game) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, 0.55),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<String?>(
              valueListenable: game.notice,
              builder: (context, text, _) => text == null
                  ? const SizedBox()
                  : Text(
                      text,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: BwColors.amber,
                      ),
                    ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: game.respawnSeconds,
              builder: (context, seconds, _) => seconds <= 0
                  ? const SizedBox()
                  : Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Panel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          tr(
                            'ZERSTÖRT  ·  WIEDER EINSATZBEREIT IN $seconds s',
                            'DESTROYED  ·  READY AGAIN IN $seconds s',
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: BwColors.danger,
                          ),
                        ),
                      ),
                    ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: game.rapidFireSeconds,
              builder: (context, seconds, _) => seconds <= 0
                  ? const SizedBox()
                  : Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Panel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          tr(
                            'SCHNELLFEUER  $seconds s',
                            'RAPID FIRE  $seconds s',
                          ),
                        ),
                      ),
                    ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: game.shieldSeconds,
              builder: (context, seconds, _) => seconds <= 0
                  ? const SizedBox()
                  : Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Panel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          tr('SCHILD  $seconds s', 'SHIELD  $seconds s'),
                          style: const TextStyle(color: Color(0xFF81D4FA)),
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
                        padding: const EdgeInsets.only(top: 6),
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
    );
  }

  Widget _status(SpaceGame game) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<double>(
                      valueListenable: game.hpNotifier,
                      builder: (context, hp, _) =>
                          HealthBar(hp: hp, maxHp: game.myMaxHp),
                    ),
                    const SizedBox(height: 6),
                    _ammo(game),
                  ],
                ),
                const Spacer(),
                Panel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _alive(game, 16),
                      ValueListenableBuilder<int>(
                        valueListenable: game.soldiersRunOver,
                        builder: (context, n, _) => n == 0
                            ? const SizedBox()
                            : Text(
                                tr('ÜBERROLLT: $n', 'RUN OVER: $n'),
                                style: const TextStyle(
                                  color: BwColors.danger,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _zoneLabel(),
                        style: const TextStyle(color: BwColors.amber),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            KillFeedView(feed: game.killFeed),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: MiniMap(game: game),
            ),
          ],
        ),
      ),
    );
  }
}

/// Defense round: how the base stands, the money, the buttons that put a
/// gun where the tank stands or upgrade the one next to it, and the
/// upgrades for the tank.
class _DefensePanel extends StatefulWidget {
  const _DefensePanel({
    required this.game,
    required this.touch,
    required this.counts,
    required this.waveLabel,
  });

  final SpaceGame game;
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
  _Shop _shop = _Shop.closed;

  SpaceGame get game => widget.game;
  bool get touch => widget.touch;

  ButtonStyle get _buttonStyle => ButtonStyle(
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: touch ? 8 : 10, vertical: 4),
    ),
    // Big enough for a thumb on phones, still a single line of text.
    minimumSize: WidgetStatePropertyAll(Size(0, touch ? 32 : 30)),
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  TextStyle get _small =>
      TextStyle(fontSize: touch ? 10 : 11, letterSpacing: 0.5);

  /// What can be bought now is filled in [color] and bright, what cannot is
  /// only a faint outline, so the two never look alike.
  ButtonStyle _buyStyle(Color color) => _buttonStyle.copyWith(
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? Colors.transparent
          : color.withValues(alpha: 0.28),
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? BwColors.textDim.withValues(alpha: 0.45)
          : BwColors.text,
    ),
    side: WidgetStateProperty.resolveWith(
      (states) => BorderSide(
        color: states.contains(WidgetState.disabled)
            ? color.withValues(alpha: 0.3)
            : color,
        width: 1.5,
      ),
    ),
  );

  Widget _nearTower(Tower near, int credits) {
    return FilledButton.icon(
      style: _buttonStyle,
      onPressed:
          near.kind.upgradable &&
              near.level < _towerLimit &&
              credits >= near.kind.upgradeCost(near.level)
          ? () => game.upgradeTower(near)
          : null,
      icon: const Icon(Icons.upgrade, size: 16),
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
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final kind in TowerKind.values)
          if (!kind.extension || extended)
            Tooltip(
              message: switch (kind.lockedIn(wave, extended: extended)) {
                final locked? => '${kind.hint}, $locked',
                null => kind.hint,
              },
              child:
                  (kind == game.towerChoice.value
                  ? FilledButton.new
                  : OutlinedButton.new)(
                    style: kind == game.towerChoice.value
                        ? _buttonStyle
                        : _buyStyle(BwColors.oliveLight),
                    onPressed:
                        credits >= kind.cost &&
                            kind.unlockedIn(wave, extended: extended)
                        ? () => game.buildTower(kind)
                        : null,
                    child: Text(
                      kind.unlockedIn(wave, extended: extended)
                          ? '${kind.label} ${kind.cost}'
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
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final kind in UpgradeKind.values) _upgrade(kind, credits),
      ],
    );
  }

  Widget _shopDesktop(int credits) {
    final near = game.nearTower.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tr(
            'MITTEL $credits   ·   B baut/rüstet auf, V wechselt',
            'FUNDS $credits   ·   B builds/upgrades, V switches',
          ),
          style: const TextStyle(
            color: BwColors.amber,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        if (near != null) _nearTower(near, credits) else _towers(credits),
        const SizedBox(height: 6),
        _upgrades(credits),
      ],
    );
  }

  Widget _tab(String label, _Shop shop) {
    final open = _shop == shop;
    return (open ? FilledButton.new : OutlinedButton.new)(
      style: _buttonStyle,
      onPressed: () => setState(() => _shop = open ? _Shop.closed : shop),
      child: Text(label, style: _small),
    );
  }

  /// Phones: a slim header with the base and the credits, the lists fold out
  /// on demand. Standing by a gun shows its upgrade button right away.
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
              tr('MITTEL $credits', 'FUNDS $credits'),
              style: const TextStyle(
                color: BwColors.amber,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            _tab(tr('TÜRME', 'TOWERS'), _Shop.towers),
            const SizedBox(width: 6),
            _tab('UPGRADES', _Shop.upgrades),
          ],
        ),
        if (near != null) ...[
          const SizedBox(height: 6),
          _nearTower(near, credits),
        ],
        if (_shop != _Shop.closed) ...[
          const SizedBox(height: 6),
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
        style: _buyStyle(kind.color).copyWith(
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: touch ? 6 : 8, vertical: 2),
          ),
          minimumSize: WidgetStatePropertyAll(Size(0, touch ? 32 : 28)),
        ),
        onPressed: !maxed && credits >= cost
            ? () => game.buyUpgrade(kind)
            : null,
        child: Text(
          '${kind.label} ${'●' * level}${'○' * (limit - level)}'
          '${maxed ? '' : ' $cost'}',
          style: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }

  /// After the last regular wave: the host extends or pulls out, everybody
  /// else learns what is at stake. In the extension the host may pull out
  /// between waves.
  Widget _decision() {
    return ValueListenableBuilder<DefensePayload?>(
      valueListenable: game.defense,
      builder: (context, state, _) {
        if (state == null ||
            state.result != DefenseResult.running ||
            state.nextWaveAt == 0 ||
            !(state.deciding || state.extended)) {
          return const SizedBox.shrink();
        }
        final host = game.round?.botHost == game.myId;
        final withdraw = OutlinedButton.icon(
          style: _buyStyle(BwColors.sand),
          onPressed: game.withdrawDefense,
          icon: const Icon(Icons.flag, size: 16),
          label: Text(tr('ABZIEHEN', 'WITHDRAW'), style: _small),
        );
        final children = <Widget>[];
        if (state.deciding) {
          children
            ..add(
              Text(
                tr(
                  'ALLE ${GameConfig.defenseWaves} WELLEN ABGEWEHRT · SIEG GESICHERT',
                  'ALL ${GameConfig.defenseWaves} WAVES REPELLED · VICTORY SECURED',
                ),
                style: TextStyle(
                  color: BwColors.amber,
                  fontSize: touch ? 11 : 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
            ..add(const SizedBox(height: 4))
            ..add(
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  tr(
                    'Verlängerung: Wellen ohne Ende mit zäheren Gegnern, Stufe 4 '
                        'und 5 für Geschütze und Panzer, Raketenwerfer und eine '
                        'Zitadelle. Fällt der Stützpunkt, bleibt der Sieg.',
                    'Extension: endless waves with tougher enemies, levels 4 '
                        'and 5 for turrets and tanks, rocket launchers and a '
                        'citadel. If the base falls, the victory remains.',
                  ),
                  style: TextStyle(fontSize: touch ? 10 : 11),
                ),
              ),
            )
            ..add(const SizedBox(height: 6))
            ..add(
              host
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        FilledButton.icon(
                          style: _buttonStyle,
                          onPressed: game.extendDefense,
                          icon: const Icon(Icons.all_inclusive, size: 16),
                          label: Text(
                            tr('VERLÄNGERN', 'EXTEND'),
                            style: _small,
                          ),
                        ),
                        withdraw,
                      ],
                    )
                  : Text(
                      tr(
                        'Der Host entscheidet, ob es weitergeht.',
                        'The host decides whether it goes on.',
                      ),
                      style: TextStyle(
                        fontSize: touch ? 10 : 11,
                        color: BwColors.textDim,
                      ),
                    ),
            );
        } else if (host) {
          children.add(withdraw);
        } else {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: EdgeInsets.only(bottom: touch ? 6 : 10),
          child: Column(
            crossAxisAlignment: touch
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        );
      },
    );
  }

  Widget _base() {
    return ValueListenableBuilder<DefensePayload?>(
      valueListenable: game.defense,
      builder: (context, state, _) {
        final hq = state?.hq ?? 1;
        final hp = state?.hp ?? GameConfig.baseHp;
        final ratio = (hp / GameConfig.baseMaxHp(hq)).clamp(0.0, 1.0);
        final bar = SizedBox(
          width: touch ? 70 : 200,
          height: touch ? 6 : 8,
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: const Color(0x66000000),
            color: ratio > 0.3 ? const Color(0xFF9CCC65) : BwColors.danger,
          ),
        );
        final label = Text(
          touch
              ? '${hp.ceil()}'
              : '${tr('STÜTZPUNKT', 'BASE')} · ${GameConfig.hqName(hq)}  ${hp.ceil()}',
          style: TextStyle(
            fontSize: touch ? 10 : 12,
            fontWeight: FontWeight.w800,
          ),
        );
        if (touch) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message:
                    '${tr('Stützpunkt', 'Base')} · ${GameConfig.hqName(hq)}',
                child: const Icon(Icons.flag, size: 12, color: BwColors.sand),
              ),
              const SizedBox(width: 4),
              bar,
              const SizedBox(width: 6),
              label,
              const SizedBox(width: 10),
              Text(
                widget.waveLabel,
                style: const TextStyle(fontSize: 11, color: BwColors.amber),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [label, const SizedBox(height: 4), bar],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final panel = Panel(
      padding: touch
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: touch
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (touch) ...[
            Text(
              widget.counts,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
          ],
          _decision(),
          _base(),
          SizedBox(height: touch ? 5 : 8),
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
      child: Align(
        alignment: touch ? Alignment.topRight : Alignment.bottomLeft,
        child: Padding(
          // Phones: in the top right corner.
          // Room for the mute button, which only the browser shows and
          // upright under the gauges.
          padding: touch
              ? EdgeInsets.only(
                  right:
                      kIsWeb &&
                          MediaQuery.sizeOf(context).width >= _uprightWidth
                      ? 44
                      : 0,
                )
              : const EdgeInsets.all(8),
          child: _HudButtons(game: game, child: panel),
        ),
      ),
    );
  }
}

/// Marks the mouse as over HUD buttons while it is, so clicking them does not
/// also fire the gun.
class _HudButtons extends StatelessWidget {
  const _HudButtons({required this.game, required this.child});

  final SpaceGame game;
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
