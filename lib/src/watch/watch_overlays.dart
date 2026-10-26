import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_watchos/flutter_watchos.dart';
import 'package:horizont/horizont.dart';

import '../game/game_config.dart';
import '../game/inventory.dart';
import '../game/tank_game.dart';
import '../l10n/l10n.dart';
import '../ui/theme.dart';
import '../ui/widgets/health_bar.dart';
import 'watch_support.dart';
import 'watch_widgets.dart';

/// What the round shows on the watch: how many tanks are left or the wave
/// as the one big value in mono, armour and magazine along the bottom, the inventory at the right edge and
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
      builder: (context, _, _) => _onPlate(
        Text(_status(), textAlign: TextAlign.center, style: GameType.dataLarge),
      ),
    ),
  );

  /// A short message in the middle, as a kill or a new wave.
  Widget _notice() => ValueListenableBuilder<String?>(
    valueListenable: game.notice,
    builder: (context, text, _) => text == null
        ? const SizedBox()
        : _onPlate(
            Text(
              text,
              textAlign: TextAlign.center,
              style: GameType.label.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
  );

  /// How long until the own tank comes back.
  Widget _respawn() => ValueListenableBuilder<int>(
    valueListenable: game.respawnSeconds,
    builder: (context, seconds, _) => seconds > 0
        ? _onPlate(
            Text(
              tr('Einsatzbereit in $seconds s', 'Ready in $seconds s'),
              textAlign: TextAlign.center,
              style: GameType.data.copyWith(fontWeight: FontWeight.w600),
            ),
          )
        : const SizedBox(),
  );

  /// A line over the moving round: on a sunken plate, a little
  /// see-through, instead of a shadow behind the letters.
  static Widget _onPlate(Widget child) => DecoratedBox(
    decoration: BoxDecoration(
      color: GameColors.sunken.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(HzRadius.r6),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HzSpace.s8,
        vertical: HzSpace.s2,
      ),
      child: child,
    ),
  );

  /// One inventory slot: tap to use it. Framed in the colour the item has
  /// in the field.
  Widget _slot(int index, InventorySlot slot, double size) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => game.useItem(index),
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: GameColors.panel,
        borderRadius: BorderRadius.circular(HzRadius.r6),
        border: Border.all(color: slot.type.color, width: HzLine.selection),
      ),
      child: Text(
        '${slot.count}',
        style: GameType.data.copyWith(fontWeight: FontWeight.w600),
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
          // Shrinks a long wave line to the width instead of cutting it.
          child: IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: HzSpace.s12),
              child: FittedBox(fit: BoxFit.scaleDown, child: _statusLine()),
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              padding.left + HzSpace.s8,
              0,
              padding.right + HzSpace.s48,
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
          left: padding.left + HzSpace.s12,
          right: padding.right + HzSpace.s12,
          bottom: padding.bottom + HzSpace.s8,
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
                    // The HUD's bar: ink while there is enough, warning
                    // and critical with the sign beside it.
                    final status = armourStatus(share);
                    return Row(
                      children: [
                        Expanded(
                          child: GaugeBar(value: share, status: status),
                        ),
                        StockSign(status),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: HzSpace.s8),
              // The magazine stays, but quiet: the one big value on the
              // watch is what is left of the battle.
              ValueListenableBuilder<int>(
                valueListenable: game.ammoNotifier,
                builder: (context, ammo, _) => _onPlate(
                  Text(
                    game.endlessAmmo ? '∞' : '$ammo',
                    style: GameType.data.copyWith(
                      color: game.endlessAmmo || game.myMagazine == 0
                          ? GameColors.textMuted
                          : stockColor(
                              ammo == 0
                                  ? HorizontStatus.critical
                                  : stockStatus(
                                      ammo / game.myMagazine,
                                      low: GameConfig.ammoLowShare,
                                    ),
                            ),
                    ),
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
          padding: const EdgeInsets.only(bottom: HzSpace.s8),
          child: SizedBox(
            height: 34,
            width: double.infinity,
            child: FilledButton(
              onPressed: ready ? () => game.buildTower(kind) : null,
              style: FilledButton.styleFrom(padding: EdgeInsets.zero),
              child: FittedBox(
                child: Text(
                  '${kind.label} ${game.buildCost(kind)} · $credits',
                  style: TextStyle(
                    fontFamily: HzFont.mono,
                    package: HzFont.package,
                    fontSize: GameType.data.fontSize,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
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
            // The one value of the screen, big in mono.
            Text(
              '$seconds',
              style: GameType.dataLarge.copyWith(fontSize: 64, height: 1),
            ),
            const SizedBox(height: HzSpace.s4),
            _WatchHudState._onPlate(
              Text(
                tr('Krone dreht, Panzer lenkt', 'Crown turns, tank steers'),
                textAlign: TextAlign.center,
                style: GameType.caption.copyWith(color: GameColors.text),
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
        // The result is a state: word, sign and colour.
        final status = won
            ? HorizontStatus.positive
            : lost
            ? HorizontStatus.critical
            : null;
        final color = status == null
            ? GameColors.text
            : won
            ? GameColors.positive
            : GameColors.critical;
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: GameColors.bg.withValues(alpha: 0.87)),
            WatchPage(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (status != null) ...[
                        Icon(status.icon, size: HzIconSize.bar, color: color),
                        const SizedBox(width: HzSpace.s8),
                      ],
                      Text(
                        won
                            ? tr('GEWONNEN', 'VICTORY')
                            : lost
                            ? tr('NIEDERLAGE', 'DEFEAT')
                            : tr('BEENDET', 'OVER'),
                        maxLines: 1,
                        style: GameType.title.copyWith(color: color),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: HzSpace.s8),
                Text(
                  tr(
                    '${stats.kills} Abschüsse · ${stats.damage.round()} Schaden',
                    '${stats.kills} kills · ${stats.damage.round()} damage',
                  ),
                  textAlign: TextAlign.center,
                  style: GameType.data.copyWith(color: GameColors.textMuted),
                ),
                const SizedBox(height: HzSpace.s12),
                ValueListenableBuilder<bool>(
                  valueListenable: game.isHost,
                  builder: (context, host, _) => WatchButton(
                    label: tr('NEUES SPIEL', 'NEW GAME'),
                    icon: HorizontSymbols.replay,
                    primary: true,
                    onPressed: host ? game.rematch : null,
                  ),
                ),
                WatchButton(
                  label: tr('WARTERAUM', 'WAITING ROOM'),
                  icon: HorizontSymbols.exitToApp,
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
              builder: (context, name, _) => Center(
                child: _WatchHudState._onPlate(
                  Text(
                    name == null
                        ? tr('Beobachte', 'Watching')
                        : tr('Beobachte $name', 'Watching $name'),
                    textAlign: TextAlign.center,
                    style: GameType.label.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          // On a round watch narrow and low, in the widest part of the
          // bottom that still holds the button.
          left: watchRound ? d * 0.25 : HzSpace.s12,
          right: watchRound ? d * 0.25 : HzSpace.s12,
          bottom: watchRound ? d * 0.03 : HzSpace.s8,
          child: WatchButton(
            label: tr('WEITER', 'NEXT'),
            icon: HorizontSymbols.skipNext,
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
            style: GameType.body,
          ),
        ),
        const SizedBox(height: HzSpace.s12),
        WatchButton(
          label: tr('STARTSEITE', 'START PAGE'),
          icon: HorizontSymbols.home,
          primary: true,
          onPressed: game.backToStart,
        ),
      ],
    );
  }
}
