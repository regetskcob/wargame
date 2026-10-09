import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_watchos/flutter_watchos.dart';

import '../game/inventory.dart';
import '../game/tank_game.dart';
import '../game/game_config.dart';
import '../l10n/l10n.dart';
import '../ui/theme.dart';
import 'watch_widgets.dart';

/// What the round shows on the watch: how many tanks are left or the wave,
/// armour and magazine along the bottom, the inventory at the right edge and
/// in a defense round a button to build a gun. Everything else stays off the
/// small screen. The crown steers, see `WatchSteering`.
class WatchHud extends StatefulWidget {
  const WatchHud({required this.game, super.key});

  final TankGame game;

  @override
  State<WatchHud> createState() => _WatchHudState();
}

class _WatchHudState extends State<WatchHud> {
  Timer? _timer;

  TankGame get game => widget.game;

  @override
  void initState() {
    super.initState();
    // The wave countdown runs on the clock, not on a notifier.
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _status() {
    final round = game.round;
    final defense = game.defense.value;
    if (round != null && round.defense && defense != null) {
      final waves = defense.extended ? '' : '/${GameConfig.defenseWaves}';
      final wait = defense.nextWaveAt - DateTime.now().millisecondsSinceEpoch;
      final label = tr(
        'Welle ${defense.wave}$waves',
        'Wave ${defense.wave}$waves',
      );
      return wait > 0 ? '$label · ${(wait / 1000).ceil()} s' : label;
    }
    return tr(
      '${game.aliveCount.value} übrig',
      '${game.aliveCount.value} left',
    );
  }

  @override
  Widget build(BuildContext context) {
    final band = WatchStatusBar.heightOf(context);
    final padding = MediaQuery.paddingOf(context);
    return Stack(
      children: [
        Positioned(
          top: band,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: ValueListenableBuilder<int>(
              valueListenable: game.aliveCount,
              builder: (context, _, _) => ValueListenableBuilder(
                valueListenable: game.defense,
                builder: (context, _, _) => Text(
                  _status(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: GameColors.text,
                    shadows: [Shadow(blurRadius: 4)],
                  ),
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              padding.left + 8,
              0,
              padding.right + 48,
              0,
            ),
            child: IgnorePointer(
              child: ValueListenableBuilder<String?>(
                valueListenable: game.notice,
                builder: (context, text, _) => text == null
                    ? const SizedBox()
                    : Text(
                        text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: GameColors.amber,
                          shadows: [Shadow(blurRadius: 4)],
                        ),
                      ),
              ),
            ),
          ),
        ),
        Positioned(
          right: padding.right + 2,
          top: 0,
          bottom: 0,
          child: Align(
            alignment: Alignment.centerRight,
            child: ValueListenableBuilder<List<InventorySlot>>(
              valueListenable: game.inventory,
              builder: (context, slots, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, slot) in slots.take(3).indexed)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => game.useItem(i),
                      child: Container(
                        width: 38,
                        height: 38,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: GameColors.panel,
                          shape: BoxShape.circle,
                          border: Border.all(color: slot.type.color, width: 2),
                        ),
                        child: Text(
                          '${slot.count}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: padding.left + 12,
          right: padding.right + 12,
          bottom: padding.bottom + 6,
          child: _bottom(),
        ),
      ],
    );
  }

  Widget _bottom() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<int>(
          valueListenable: game.respawnSeconds,
          builder: (context, seconds, _) => seconds > 0
              ? Text(
                  tr('Zurück in $seconds s', 'Back in $seconds s'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: GameColors.amber,
                  ),
                )
              : const SizedBox(),
        ),
        if (game.round?.defense ?? false) _build(),
        IgnorePointer(
          child: Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<double>(
                  valueListenable: game.hpNotifier,
                  builder: (context, hp, _) {
                    final share = (hp / game.myMaxHp).clamp(0.0, 1.0);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: share,
                        minHeight: 8,
                        backgroundColor: const Color(0x88000000),
                        color: share > 0.3
                            ? GameColors.oliveLight
                            : GameColors.danger,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<int>(
                valueListenable: game.ammoNotifier,
                builder: (context, ammo, _) => Text(
                  game.endlessAmmo ? '∞' : '$ammo',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: GameColors.amber,
                    shadows: [Shadow(blurRadius: 4)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the chosen gun next to the tank, when the funds are there.
  Widget _build() {
    return ValueListenableBuilder<int>(
      valueListenable: game.credits,
      builder: (context, credits, _) {
        final kind = game.towerChoice.value;
        final wave = game.defense.value?.wave ?? 0;
        final extended = game.defense.value?.extended ?? false;
        final ready =
            credits >= kind.cost && kind.unlockedIn(wave, extended: extended);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: SizedBox(
            height: 34,
            width: double.infinity,
            child: FilledButton(
              onPressed: ready ? () => game.buildTower(kind) : null,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: GameColors.olive,
              ),
              child: FittedBox(
                child: Text(
                  '${kind.label} ${kind.cost} · $credits',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The count before the round, big in the middle.
class WatchCountdown extends StatefulWidget {
  const WatchCountdown({required this.game, super.key});

  final TankGame game;

  @override
  State<WatchCountdown> createState() => _WatchCountdownState();
}

class _WatchCountdownState extends State<WatchCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startedAt = widget.game.round?.startedAt ?? 0;
    final ms = startedAt - DateTime.now().millisecondsSinceEpoch;
    final seconds = (ms / 1000).ceil().clamp(0, 9);
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$seconds',
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w900,
                color: GameColors.amber,
                shadows: [Shadow(blurRadius: 8)],
              ),
            ),
            Text(
              tr('Krone dreht, Panzer lenkt', 'Crown turns, tank steers'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: GameColors.text,
                shadows: [Shadow(blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// End of the round: result, a few numbers and the way on.
class WatchRoundOver extends StatelessWidget {
  const WatchRoundOver({required this.game, super.key});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RoundOutcome>(
      valueListenable: game.outcome,
      builder: (context, outcome, _) {
        final won = outcome == RoundOutcome.won;
        final lost = outcome == RoundOutcome.lost;
        final stats = game.roundStats;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xDD161C0F)),
            WatchPage(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    won
                        ? tr('SIEG', 'VICTORY')
                        : lost
                        ? tr('NIEDERLAGE', 'DEFEAT')
                        : tr('BEENDET', 'OVER'),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: won
                          ? GameColors.amber
                          : lost
                          ? GameColors.danger
                          : GameColors.sand,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tr(
                    '${stats.kills} Abschüsse · ${stats.damage.round()} Schaden',
                    '${stats.kills} kills · ${stats.damage.round()} damage',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: GameColors.textDim,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<bool>(
                  valueListenable: game.isHost,
                  builder: (context, host, _) => WatchButton(
                    label: tr('NOCHMAL', 'REMATCH'),
                    icon: Icons.replay,
                    primary: true,
                    onPressed: host ? game.rematch : null,
                  ),
                ),
                WatchButton(
                  label: tr('WARTERAUM', 'WAITING ROOM'),
                  icon: Icons.exit_to_app,
                  onPressed: game.backToLobby,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Watching somebody else after the own tank fell.
class WatchSpectator extends StatelessWidget {
  const WatchSpectator({required this.game, super.key});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    final band = WatchStatusBar.heightOf(context);
    return Stack(
      children: [
        Positioned(
          top: band,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: ValueListenableBuilder<String?>(
              valueListenable: game.spectatingName,
              builder: (context, name, _) => Text(
                name == null
                    ? tr('Du schaust zu', 'You are watching')
                    : tr('Du schaust $name zu', 'Watching $name'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(blurRadius: 4)],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 8,
          child: WatchButton(
            label: tr('WEITER', 'NEXT'),
            icon: Icons.skip_next,
            onPressed: game.spectateNext,
          ),
        ),
      ],
    );
  }
}

/// The room closed: back to the start page.
class WatchClosed extends StatelessWidget {
  const WatchClosed({required this.game, super.key});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    return WatchPage(
      children: [
        ValueListenableBuilder<String?>(
          valueListenable: game.closedReason,
          builder: (context, reason, _) => Text(
            reason ?? tr('Raum geschlossen', 'Room closed'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        WatchButton(
          label: tr('STARTSEITE', 'START PAGE'),
          icon: Icons.home,
          primary: true,
          onPressed: game.backToStart,
        ),
      ],
    );
  }
}
