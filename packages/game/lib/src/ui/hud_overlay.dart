import 'dart:async';

import 'package:flutter/material.dart';

import '../game/components/storm_zone.dart';
import '../game/space_game.dart';
import '../game_config.dart';
import '../theme.dart';
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

  String _zoneLabel() {
    final round = widget.game.round;
    if (round == null) {
      return '';
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final graceEndsAt =
        round.startedAt + GameConfig.zoneGraceSeconds.toInt() * 1000;
    if (now < graceEndsAt) {
      final seconds = ((graceEndsAt - now) / 1000).ceil();
      return 'Sperrgebiet wird in $seconds s zugezogen';
    }
    final radius = StormZone.radiusAt(round.startedAt, now);
    if (radius <= GameConfig.zoneMinRadius) {
      return 'Sperrgebiet vollständig geschlossen';
    }
    return 'Sperrgebiet zieht sich zu: sicherer Radius ${radius.round()}';
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return Stack(
      children: [
        _status(game),
        _effects(game),
        const Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: 12),
            child: MuteButton(),
          ),
        ),
        EnemyIndicators(game: game),
        ValueListenableBuilder<bool>(
          valueListenable: game.touchMode,
          builder: (context, touch, _) =>
              touch ? TouchControls(input: game.touch) : const SizedBox(),
        ),
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
                ValueListenableBuilder<double>(
                  valueListenable: game.hpNotifier,
                  builder: (context, hp, _) =>
                      HealthBar(hp: hp, maxHp: game.myMaxHp),
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
                      ValueListenableBuilder<int>(
                        valueListenable: game.aliveCount,
                        builder: (context, alive, _) {
                          const style = TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          );
                          final round = game.round;
                          if (round != null && round.teamMode) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'ROT ${round.aliveIn(1)}',
                                  style: style.copyWith(
                                    color: GameConfig.teamColors[1],
                                  ),
                                ),
                                const Text('   ', style: style),
                                Text(
                                  'BLAU ${round.aliveIn(2)}',
                                  style: style.copyWith(
                                    color: GameConfig.teamColors[2],
                                  ),
                                ),
                              ],
                            );
                          }
                          return Text('$alive PANZER IM FELD', style: style);
                        },
                      ),
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
            // With touch controls both thumbs own the lower corners, so the
            // map moves to the middle.
            ValueListenableBuilder<bool>(
              valueListenable: game.touchMode,
              builder: (context, touch, _) => Align(
                alignment: touch
                    ? Alignment.bottomCenter
                    : Alignment.bottomRight,
                child: MiniMap(game: game, size: touch ? 104 : 150),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
