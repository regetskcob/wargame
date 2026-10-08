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
          ? 'Sperrgebiet in $seconds s'
          : 'Sperrgebiet wird in $seconds s zugezogen';
    }
    final radius = StormZone.radiusAt(round.startedAt, now);
    if (radius <= GameConfig.zoneMinRadius) {
      return compact ? 'Sperrgebiet zu' : 'Sperrgebiet vollständig geschlossen';
    }
    return compact
        ? 'Sicher: Radius ${radius.round()}'
        : 'Sperrgebiet zieht sich zu: sicherer Radius ${radius.round()}';
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
      return compact
          ? 'Welle ${state.wave + 1} in $seconds s'
          : 'Nächste Welle in $seconds s';
    }
    return compact ? 'Welle läuft' : 'Welle läuft: Haltet die Straße';
  }

  /// Wave, enemies and comrades in one short line, for the phone panel.
  String _waveCounts() {
    final game = widget.game;
    final round = game.round;
    final allies = round == null ? 0 : round.alive.where(round.isAlly).length;
    return 'WELLE ${game.defense.value?.wave ?? 0}/${GameConfig.defenseWaves}'
        ' · FEINDE ${game.enemiesOnField} · KAM. $allies';
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
              'WELLE ${state?.wave ?? 0}/${GameConfig.defenseWaves}'
              '   FEINDE $enemies   KAMERADEN $allies',
              style: style,
            ),
          );
        }
        if (round != null && round.teamMode) {
          return Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'ROT ${round.aliveIn(1)}',
                  style: TextStyle(color: GameConfig.teamColors[1]),
                ),
                const TextSpan(text: '   '),
                TextSpan(
                  text: 'BLAU ${round.aliveIn(2)}',
                  style: TextStyle(color: GameConfig.teamColors[2]),
                ),
              ],
            ),
            style: style,
          );
        }
        return Text('$alive PANZER IM FELD', style: style);
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
                                  fontSize: 10,
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
                          'ZERSTÖRT  ·  WIEDER EINSATZBEREIT IN $seconds s',
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
                        child: Text('SCHNELLFEUER  $seconds s'),
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
                          'SCHILD  $seconds s',
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
                                'ÜBERROLLT: $n',
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

  Widget _nearTower(Tower near, int credits) {
    return FilledButton.icon(
      style: _buttonStyle,
      onPressed:
          near.kind.upgradable &&
              near.level < TowerKind.maxLevel &&
              credits >= near.kind.upgradeCost(near.level)
          ? () => game.upgradeTower(near)
          : null,
      icon: const Icon(Icons.upgrade, size: 16),
      label: Text(
        !near.kind.upgradable
            ? '${near.kind.label} BESETZT'
            : near.level >= TowerKind.maxLevel
            ? '${near.kind.label} HÖCHSTE STUFE'
            : '${near.kind.label} AUFRÜSTEN  '
                  '${near.kind.upgradeCost(near.level)}',
        style: _small,
      ),
    );
  }

  Widget _towers(int credits) {
    final wave = game.defense.value?.wave ?? 0;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final kind in TowerKind.values)
          Tooltip(
            message: kind.unlockedIn(wave)
                ? kind.hint
                : '${kind.hint}, ab Welle ${kind.fromWave}',
            child:
                (kind == game.towerChoice.value
                ? FilledButton.new
                : OutlinedButton.new)(
                  style: _buttonStyle,
                  onPressed: credits >= kind.cost && kind.unlockedIn(wave)
                      ? () => game.buildTower(kind)
                      : null,
                  child: Text(
                    kind.unlockedIn(wave)
                        ? '${kind.label} ${kind.cost}'
                        : '${kind.label} AB W${kind.fromWave}',
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
          'MITTEL $credits   ·   B baut/rüstet auf, V wechselt',
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
              'MITTEL $credits',
              style: const TextStyle(
                color: BwColors.amber,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            _tab('TÜRME', _Shop.towers),
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
    final maxed = level >= GameConfig.upgradeMaxLevel;
    final cost = kind.costFrom(level);
    return Tooltip(
      message: '${kind.label}: ${kind.effect} je Stufe',
      child: OutlinedButton(
        style: _buttonStyle.copyWith(
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: touch ? 6 : 8, vertical: 2),
          ),
          minimumSize: WidgetStatePropertyAll(Size(0, touch ? 32 : 28)),
          side: WidgetStatePropertyAll(BorderSide(color: kind.color)),
        ),
        onPressed: !maxed && credits >= cost
            ? () => game.buyUpgrade(kind)
            : null,
        child: Text(
          '${kind.label} ${'●' * level}${'○' * (GameConfig.upgradeMaxLevel - level)}'
          '${maxed ? '' : ' $cost'}',
          style: TextStyle(fontSize: 10, color: kind.color),
        ),
      ),
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
              : 'STÜTZPUNKT · ${GameConfig.hqName(hq)}  ${hp.ceil()}',
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
                message: 'Stützpunkt · ${GameConfig.hqName(hq)}',
                child: const Icon(Icons.flag, size: 12, color: BwColors.sand),
              ),
              const SizedBox(width: 4),
              bar,
              const SizedBox(width: 6),
              label,
              const SizedBox(width: 10),
              Text(
                widget.waveLabel,
                style: const TextStyle(fontSize: 10, color: BwColors.amber),
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
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
          ],
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
