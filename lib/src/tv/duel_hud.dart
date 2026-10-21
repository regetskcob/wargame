import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../game/game_config.dart';
import '../game/inventory.dart';
import '../game/tank_game.dart';
import '../l10n/l10n.dart';
import '../net/payloads/defense_payload.dart';
import '../ui/theme.dart';
import '../ui/widgets/health_bar.dart';
import '../ui/widgets/panel.dart';
import 'seats.dart';
import 'tv_input.dart';

/// The HUD of a duel on the overview of the whole field: the wave and both
/// bases on top, each player's tank, funds and inventory in their corner,
/// red bottom left, blue bottom right.
class DuelOverviewHud extends StatelessWidget {
  const DuelOverviewHud({required this.game, super.key});

  /// The first player's game, which shows the field.
  final TankGame game;

  @override
  Widget build(BuildContext context) {
    final partner = game.partner;
    return SafeArea(
      minimum: const EdgeInsets.all(HzSpace.s12),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: _Bases(game: game),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: _PlayerPanel(game: game, player: 0),
          ),
          if (partner != null)
            Align(
              alignment: Alignment.bottomRight,
              child: _PlayerPanel(game: partner, player: 1),
            ),
        ],
      ),
    );
  }
}

/// The wave, and how both bases stand.
class _Bases extends StatelessWidget {
  const _Bases({required this.game});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DefensePayload?>(
      valueListenable: game.defense,
      builder: (context, state, _) {
        final wave = state?.wave ?? 0;
        final next = state?.nextWaveAt ?? 0;
        final left = next > 0
            ? ((next - DateTime.now().millisecondsSinceEpoch) / 1000).ceil()
            : 0;
        return Panel(
          padding: const EdgeInsets.fromLTRB(
            HzSpace.s16,
            HzSpace.s12,
            HzSpace.s16,
            HzSpace.s12,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _base(state, 0),
              const SizedBox(width: HzSpace.s24),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${tr('WELLE', 'WAVE')} $wave',
                    style: GameType.dataLarge,
                  ),
                  Text(
                    left > 0
                        ? tr('nächste in $left s', 'next in $left s')
                        : tr('läuft', 'on'),
                    style: GameType.callout.copyWith(
                      color: GameColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: HzSpace.s24),
              _base(state, 1),
            ],
          ),
        );
      },
    );
  }

  Widget _base(DefensePayload? state, int lane) {
    final hp = state?.hpOf(lane) ?? GameConfig.baseHp;
    final hq = state?.hqOf(lane) ?? 1;
    final ratio = (hp / GameConfig.baseMaxHp(hq)).clamp(0.0, 1.0);
    final color = playerColors[lane];
    return Column(
      crossAxisAlignment: lane == 0
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${lane == 0 ? tr('ROT', 'RED') : tr('BLAU', 'BLUE')} · '
          '${GameConfig.hqName(hq)}  ${hp.ceil()}',
          style: GameType.data.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: HzSpace.s4),
        // Each side's base in its colour, which names it on the field.
        SizedBox(
          width: 220,
          child: GaugeBar(value: ratio, color: color),
        ),
      ],
    );
  }
}

/// One player's tank, funds, weapon and inventory, and what happened to
/// them last.
class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({required this.game, required this.player});

  final TankGame game;
  final int player;

  @override
  Widget build(BuildContext context) {
    final color = playerColors[player];
    final right = player == 1;
    return ListenableBuilder(
      listenable: Listenable.merge([
        game.hpNotifier,
        game.ammoNotifier,
        game.credits,
        game.specialNotifier,
        game.inventory,
        game.notice,
        game.respawnSeconds,
        game.towerChoice,
        TvInput.instance.count,
      ]),
      builder: (context, _) {
        final hp = (game.hpNotifier.value / game.myMaxHp).clamp(0.0, 1.0);
        final armour = armourStatus(hp);
        final respawn = game.respawnSeconds.value;
        final special = game.specialNotifier.value;
        final pad = steeredByPad(game);
        final notice = game.notice.value;
        // A plate like every other; the player's colour is in the name.
        return Panel(
          padding: const EdgeInsets.fromLTRB(
            HzSpace.s16,
            HzSpace.s12,
            HzSpace.s16,
            HzSpace.s12,
          ),
          child: SizedBox(
            width: 300,
            child: Column(
              crossAxisAlignment: right
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${tr('SPIELER', 'PLAYER')} ${player + 1}',
                  style: GameType.title.copyWith(color: color),
                ),
                const SizedBox(height: HzSpace.s8),
                if (respawn > 0)
                  Text(
                    tr('Einsatzbereit in $respawn s', 'Ready in $respawn s'),
                    style: GameType.callout,
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: GaugeBar(value: hp, status: armour),
                      ),
                      StockSign(armour),
                    ],
                  ),
                const SizedBox(height: HzSpace.s8),
                Text(
                  '${tr('MUNITION', 'AMMO')} ${game.ammoNotifier.value}'
                  '   ·   ${tr('MÜNZEN', 'COINS')} ${game.credits.value}',
                  style: GameType.data.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${game.towerChoice.value.label} '
                  '${game.buildCost(game.towerChoice.value)}'
                  '${pad ? '  ·  R1 ${tr('baut', 'builds')}  ·  Y ${tr('Panzer', 'tank')} ${GameConfig.troopCost}' : ''}',
                  style: GameType.caption,
                ),
                if (special != null)
                  Text(
                    '${special.$1.label} ${special.$2}'
                    '${pad ? '  ·  L2' : ''}',
                    style: GameType.caption.copyWith(color: GameColors.text),
                  ),
                if (game.inventory.value.isNotEmpty) ...[
                  const SizedBox(height: HzSpace.s8),
                  _Items(slots: game.inventory.value, pad: pad),
                ],
                if (notice != null) ...[
                  const SizedBox(height: HzSpace.s8),
                  Text(
                    notice,
                    style: GameType.label.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The inventory in a row, each slot with the button that sets it off.
class _Items extends StatelessWidget {
  const _Items({required this.slots, required this.pad});

  final List<InventorySlot> slots;
  final bool pad;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: HzSpace.s8,
      runSpacing: HzSpace.s8,
      children: [
        for (final (i, slot) in slots.indexed)
          Plate(
            padding: const EdgeInsets.symmetric(
              horizontal: HzSpace.s8,
              vertical: HzSpace.s4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pad && i < tvDuelSlotLabels.length)
                  Text('${tvDuelSlotLabels[i]} ', style: GameType.kennung),
                // The icon keeps the colour of the item's crate in the field.
                Icon(
                  slot.type.icon,
                  size: HzIconSize.inline,
                  color: slot.type.color,
                ),
                if (slot.count > 1)
                  Text(
                    ' ×${slot.count}',
                    style: GameType.kennung.copyWith(color: GameColors.text),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The end of a duel on the overview: which side won.
class DuelOverviewResult extends StatelessWidget {
  const DuelOverviewResult({required this.game, super.key});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    final fell = game.defense.value?.fell ?? -1;
    final winner = fell == 0 ? 1 : (fell == 1 ? 0 : -1);
    final title = winner < 0
        ? tr('UNENTSCHIEDEN', 'DRAW')
        : winner == 0
        ? tr('ROT GEWINNT', 'RED WINS')
        : tr('BLAU GEWINNT', 'BLUE WINS');
    return ColoredBox(
      color: GameColors.bg.withValues(alpha: 0.6),
      child: Center(
        child: Panel(
          padding: const EdgeInsets.symmetric(
            horizontal: HzSpace.s32,
            vertical: HzSpace.s24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: winner < 0 ? GameColors.text : playerColors[winner],
                ),
              ),
              const SizedBox(height: HzSpace.s8),
              Text(
                winner < 0
                    ? tr(
                        'Beide Stützpunkte sind zugleich gefallen.',
                        'Both bases fell at the same time.',
                      )
                    : tr(
                        'Der Stützpunkt von '
                            '${winner == 0 ? 'Blau' : 'Rot'} ist gefallen.',
                        'The base of ${winner == 0 ? 'blue' : 'red'} fell.',
                      ),
                style: GameType.body.copyWith(color: GameColors.textMuted),
              ),
              const SizedBox(height: HzSpace.s4),
              Text(
                tr(
                  'Gleich geht es zurück in den Warteraum.',
                  'Back to the waiting room in a moment.',
                ),
                style: GameType.body.copyWith(color: GameColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
