import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_watchos/flutter_watchos.dart';

import '../game/inventory.dart';
import '../game/tank_game.dart';
import '../l10n/l10n.dart';
import '../ui/theme.dart';
import 'watch_support.dart';
import 'watch_widgets.dart';

/// What the round shows on the watch: how many tanks are left or the wave,
/// armour and magazine along the bottom, the inventory at the right edge and
/// in a defense round a button to build a gun. Everything else stays off the
/// small screen. The crown steers, see `WatchSteering`.
///
/// A round watch loses the corners, so there armour and magazine run as
/// arcs along the rim and the inventory sits on a ring above the bottom.
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
      final last = defense.lastWave;
      final waves = last == null ? '' : '/$last';
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
  Widget build(BuildContext context) =>
      watchRound ? _round(context) : _square(context);

  /// Tanks left or the wave, at the top.
  Widget _statusLine() => ValueListenableBuilder<int>(
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
  );

  /// A short message in the middle, as a kill or a new wave.
  Widget _notice() => ValueListenableBuilder<String?>(
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
  );

  /// How long until the own tank comes back.
  Widget _respawn() => ValueListenableBuilder<int>(
    valueListenable: game.respawnSeconds,
    builder: (context, seconds, _) => seconds > 0
        ? Text(
            tr('Zurück in $seconds s', 'Back in $seconds s'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: GameColors.amber,
              shadows: [Shadow(blurRadius: 4)],
            ),
          )
        : const SizedBox(),
  );

  /// One inventory slot: tap to use it.
  Widget _slot(int index, InventorySlot slot, double size) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => game.useItem(index),
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: GameColors.panel,
        shape: BoxShape.circle,
        border: Border.all(color: slot.type.color, width: 2),
      ),
      child: Text(
        '${slot.count}',
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
      ),
    ),
  );

  Widget _square(BuildContext context) {
    final band = WatchStatusBar.heightOf(context);
    final padding = MediaQuery.paddingOf(context);
    return Stack(
      children: [
        Positioned(
          top: band,
          left: 0,
          right: 0,
          child: IgnorePointer(child: _statusLine()),
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
            child: IgnorePointer(child: _notice()),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: _slot(i, slot, 38),
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

  /// Slots on the ring above the bottom are this far apart (radians):
  /// three fit between the arcs of armour and magazine.
  static const _slotStep = pi / 6;

  /// Slot [index] of [count] on the ring of radius [ring] around [center],
  /// the first on the left, the row centred on the bottom.
  Widget _ringSlot(
    int index,
    InventorySlot slot,
    int count,
    Offset center,
    double ring,
  ) {
    final angle = pi / 2 - (index - (count - 1) / 2) * _slotStep;
    return Positioned(
      left: center.dx + ring * cos(angle) - _ringSlotSize / 2,
      top: center.dy + ring * sin(angle) - _ringSlotSize / 2,
      child: _slot(index, slot, _ringSlotSize),
    );
  }

  static const _ringSlotSize = 32.0;

  Widget _round(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final d = size.shortestSide;
    final center = size.center(Offset.zero);
    // The ring of the inventory, inside the gauges on the rim.
    final ring = d / 2 - 26;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                game.hpNotifier,
                game.ammoNotifier,
              ]),
              builder: (context, _) => CustomPaint(
                painter: WatchRimPainter(
                  armour: game.hpNotifier.value / game.myMaxHp,
                  ammo: game.endlessAmmo
                      ? null
                      : game.ammoNotifier.value / max(1, game.myMagazine),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: d * 0.1,
          left: d * 0.2,
          right: d * 0.2,
          child: IgnorePointer(
            child: FittedBox(fit: BoxFit.scaleDown, child: _statusLine()),
          ),
        ),
        Positioned(
          top: d * 0.22,
          left: d * 0.2,
          right: d * 0.2,
          child: IgnorePointer(
            child: FittedBox(fit: BoxFit.scaleDown, child: _respawn()),
          ),
        ),
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: d * 0.12),
            child: IgnorePointer(child: _notice()),
          ),
        ),
        if (game.round?.defense ?? false)
          Positioned(
            // Below the own tank in the middle, above the inventory.
            top: center.dy + d * 0.09,
            left: d * 0.22,
            right: d * 0.22,
            child: _build(),
          ),
        Positioned.fill(
          child: ValueListenableBuilder<List<InventorySlot>>(
            valueListenable: game.inventory,
            builder: (context, slots, _) {
              final shown = slots.take(3).toList();
              return Stack(
                children: [
                  for (final (i, slot) in shown.indexed)
                    _ringSlot(i, slot, shown.length, center, ring),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _bottom() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _respawn(),
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
            credits >= game.buildCost(kind) &&
            kind.unlockedIn(wave, extended: extended);
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
                  '${kind.label} ${game.buildCost(kind)} · $credits',
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
    final insets = watchInsets(context);
    final d = MediaQuery.sizeOf(context).shortestSide;
    return Stack(
      children: [
        Positioned(
          top: watchRound ? insets.top : band,
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
          // On a round watch narrow and low, in the widest part of the
          // bottom that still holds the button.
          left: watchRound ? d * 0.25 : 12,
          right: watchRound ? d * 0.25 : 12,
          bottom: watchRound ? d * 0.03 : 8,
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
