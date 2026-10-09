import 'package:flutter/material.dart';

import '../game/game_config.dart';
import '../game/inventory.dart';
import '../game/tank_game.dart';
import '../l10n/l10n.dart';
import '../net/payloads/defense_payload.dart';
import '../ui/theme.dart';
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
      minimum: const EdgeInsets.all(12),
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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _base(state, 0),
              const SizedBox(width: 24),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${tr('WELLE', 'WAVE')} $wave',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    left > 0
                        ? tr('nächste in $left s', 'next in $left s')
                        : tr('läuft', 'on'),
                    style: const TextStyle(color: GameColors.amber),
                  ),
                ],
              ),
              const SizedBox(width: 24),
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
          style: TextStyle(fontWeight: FontWeight.w800, color: color),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 220,
          height: 10,
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: const Color(0x66000000),
            color: color,
          ),
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
        final respawn = game.respawnSeconds.value;
        final special = game.specialNotifier.value;
        final pad = steeredByPad(game);
        final notice = game.notice.value;
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: GameColors.panel,
            shape: GameShapes.card(edge: color, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (respawn > 0)
                    Text(
                      tr(
                        'Neuer Panzer in $respawn s',
                        'New tank in $respawn s',
                      ),
                      style: const TextStyle(color: GameColors.amber),
                    )
                  else
                    SizedBox(
                      height: 8,
                      child: LinearProgressIndicator(
                        value: hp,
                        backgroundColor: const Color(0x66000000),
                        color: hp > 0.3
                            ? const Color(0xFF9CCC65)
                            : GameColors.danger,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    '${tr('MUNITION', 'AMMO')} ${game.ammoNotifier.value}'
                    '   ·   ${tr('MITTEL', 'FUNDS')} ${game.credits.value}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${game.towerChoice.value.label} '
                    '${game.towerChoice.value.cost}'
                    '${pad ? '  ·  R1 ${tr('baut', 'builds')}  ·  Y ${tr('Panzer', 'tank')} ${GameConfig.troopCost}' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: GameColors.textDim,
                    ),
                  ),
                  if (special != null)
                    Text(
                      '${special.$1.label} ${special.$2}'
                      '${pad ? '  ·  L2' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: GameColors.amber,
                      ),
                    ),
                  if (game.inventory.value.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _Items(slots: game.inventory.value, pad: pad),
                  ],
                  if (notice != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      notice,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: GameColors.amber,
                      ),
                    ),
                  ],
                ],
              ),
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
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (i, slot) in slots.indexed)
          DecoratedBox(
            decoration: ShapeDecoration(
              color: const Color(0x55000000),
              shape: GameShapes.chip(edge: slot.type.color),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pad && i < tvDuelSlotLabels.length)
                    Text(
                      '${tvDuelSlotLabels[i]} ',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: GameColors.sand,
                      ),
                    ),
                  Icon(slot.type.icon, size: 16, color: slot.type.color),
                  if (slot.count > 1)
                    Text(
                      ' ×${slot.count}',
                      style: TextStyle(fontSize: 11, color: slot.type.color),
                    ),
                ],
              ),
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
      color: const Color(0x99000000),
      child: Center(
        child: Panel(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: winner < 0 ? GameColors.sand : playerColors[winner],
                ),
              ),
              const SizedBox(height: 8),
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
                style: const TextStyle(color: GameColors.textDim),
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  'Gleich geht es zurück in den Warteraum.',
                  'Back to the waiting room in a moment.',
                ),
                style: const TextStyle(color: GameColors.textDim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
