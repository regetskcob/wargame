import 'dart:async';

import 'package:flutter/material.dart';

import '../game/components/storm_zone.dart';
import '../net/payloads/defense_payload.dart';
import '../game/special_weapon.dart';
import '../game/space_game.dart';
import '../game_config.dart';
import '../theme.dart';
import 'widgets/ammo_gauge.dart';
import 'widgets/enemy_indicators.dart';
import 'widgets/health_bar.dart';
import 'widgets/kill_feed_view.dart';
import 'widgets/mini_map.dart';
import 'widgets/mute_button.dart';
import 'widgets/panel.dart';
import 'widgets/touch_controls.dart';

class HudOverlay extends StatefulWidget {
  const HudOverlay({required this.game, super.key});

  final SpaceGame game;

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

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
            TouchControls(input: game.touch, special: game.specialNotifier),
          if (game.round?.defense ?? false)
            _DefensePanel(game: game, touch: touch),
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
          final enemies = round.alive.where(round.isEnemy).length;
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
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<double>(
                    valueListenable: game.hpNotifier,
                    builder: (context, hp, _) =>
                        HealthBar(hp: hp, maxHp: game.myMaxHp, compact: true),
                  ),
                  const SizedBox(height: 4),
                  _ammo(game, compact: true),
                  KillFeedView(feed: game.killFeed, compact: true),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: MiniMap(game: game, size: 88),
          ),
          Align(
            alignment: Alignment.topRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const MuteButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ammo(SpaceGame game, {bool compact = false}) {
    return ValueListenableBuilder<int>(
      valueListenable: game.ammoNotifier,
      builder: (context, ammo, _) =>
          AmmoGauge(ammo: ammo, maxAmmo: game.myStats.ammo, compact: compact),
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

/// Defense round: how the base stands, the money and the button that puts a
/// gun where the tank stands.
class _DefensePanel extends StatelessWidget {
  const _DefensePanel({required this.game, required this.touch});

  final SpaceGame game;
  final bool touch;

  @override
  Widget build(BuildContext context) {
    final panel = Panel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<DefensePayload?>(
            valueListenable: game.defense,
            builder: (context, state, _) {
              final hp = state?.hp ?? GameConfig.baseHp;
              final ratio = (hp / GameConfig.baseHp).clamp(0.0, 1.0);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'STÜTZPUNKT  ${hp.ceil()}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: touch ? 140 : 200,
                    height: 8,
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: const Color(0x66000000),
                      color: ratio > 0.3
                          ? const Color(0xFF9CCC65)
                          : BwColors.danger,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<int>(
            valueListenable: game.credits,
            builder: (context, credits, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MITTEL $credits',
                  style: const TextStyle(
                    color: BwColors.amber,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: credits >= GameConfig.towerCost
                      ? game.buildTower
                      : null,
                  icon: const Icon(Icons.add_location_alt, size: 18),
                  label: Text(
                    touch
                        ? 'GESCHÜTZ ${GameConfig.towerCost}'
                        : 'GESCHÜTZ (B)  ${GameConfig.towerCost}',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return SafeArea(
      minimum: const EdgeInsets.all(8),
      child: Align(
        // Phones: below the plate with the waves, clear of both thumbs.
        alignment: touch ? Alignment.topRight : Alignment.bottomLeft,
        child: Padding(
          padding: touch
              ? const EdgeInsets.only(top: 58)
              : const EdgeInsets.all(8),
          child: panel,
        ),
      ),
    );
  }
}
