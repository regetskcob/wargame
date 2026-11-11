import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../../game/pilot_progress.dart';
import '../../game/progress.dart';
import '../../game/components/tank_painter.dart';
import '../../db/supabase_schema.g.dart';
import '../../store/product.dart';
import '../theme.dart';
import 'panel.dart';
import '../../l10n/l10n.dart';

/// Rank with the way to the next one and the rating in one line. The
/// badges fold out on demand. A sunken box with the hairline, values in
/// mono, so it reads as status and leaves the accent to the ways to play.
class PilotCard extends StatefulWidget {
  const PilotCard({required this.progress, this.owned, super.key});

  final PilotProgress progress;

  /// What the account bought, for the supporter star; null while purchases
  /// are off.
  final ValueListenable<Set<Product>>? owned;

  @override
  State<PilotCard> createState() => _PilotCardState();
}

class _PilotCardState extends State<PilotCard> {
  var _badgesOpen = false;

  /// The service record of the commander pack, read when the card opens.
  List<TankScoresRow>? _record;

  PilotProgress get progress => widget.progress;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        progress.rank,
        progress.rating,
        progress.badges,
        ?widget.owned,
      ]),
      builder: (context, _) {
        final rank = progress.rank.value;
        final rating = progress.rating.value;
        final supporter =
            widget.owned?.value.contains(Product.supporter) ?? false;
        final commander =
            widget.owned?.value.contains(Product.commander) ?? false;
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HzSpace.s12,
            vertical: HzSpace.s8,
          ),
          decoration: ShapeDecoration(
            color: GameColors.sunken,
            shape: GameShapes.chip(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  RankBadge(level: rank.level, size: 28),
                  const SizedBox(width: HzSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${supporter ? '★ ' : ''}${commander ? '◆ ' : ''}'
                          '${rank.title.toUpperCase()} · ${tr('STUFE', 'LEVEL')} ${rank.level}',
                          style: GameType.kennung,
                        ),
                        const SizedBox(height: HzSpace.s4),
                        LinearProgressIndicator(
                          value: rank.progress,
                          minHeight: HzSpace.s4,
                          borderRadius: BorderRadius.zero,
                          backgroundColor: GameColors.line,
                          color: GameColors.text,
                        ),
                        const SizedBox(height: HzSpace.s4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${rank.inRank} / ${rank.step} ${tr('EP', 'XP')}',
                                maxLines: 1,
                                softWrap: false,
                                style: GameType.data.copyWith(
                                  fontSize: 12,
                                  color: GameColors.textMuted,
                                ),
                              ),
                            ),
                            _badgeToggle(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        rating == null ? '–' : '$rating',
                        style: GameType.data.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Kennung(tr('Wertung', 'Rating')),
                    ],
                  ),
                ],
              ),
              if (_badgesOpen) ...[
                const SizedBox(height: HzSpace.s12),
                Wrap(
                  spacing: HzSpace.s8,
                  runSpacing: HzSpace.s8,
                  children: [
                    for (final achievement in Achievement.all)
                      BadgeChip(
                        achievement: achievement,
                        earned: progress.badges.value.contains(
                          achievement.code,
                        ),
                      ),
                  ],
                ),
                if (commander) ..._serviceRecord(),
              ],
            ],
          ),
        );
      },
    );
  }

  void _toggle() {
    setState(() => _badgesOpen = !_badgesOpen);
    if (_badgesOpen &&
        widget.owned?.value.contains(Product.commander) == true) {
      unawaited(_readRecord());
    }
  }

  Future<void> _readRecord() async {
    final rows = await progress.scores.myTankScores();
    if (mounted) {
      setState(() => _record = rows);
    }
  }

  /// The score per vehicle, most rounds first; the server has kept these
  /// numbers all along, the pack opens them up.
  List<Widget> _serviceRecord() {
    final rows = [...?_record]
      ..sort((a, b) => (b.rounds ?? 0).compareTo(a.rounds ?? 0));
    return [
      const SizedBox(height: HzSpace.s12),
      Kennung(tr('Einsatzakte', 'Service record')),
      const SizedBox(height: HzSpace.s4),
      if (rows.isEmpty)
        Text(
          tr('Noch keine gewerteten Runden.', 'No rated rounds yet.'),
          style: GameType.caption,
        ),
      for (final row in rows)
        if (row.tankType != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${TankType.values[row.tankType! % TankType.values.length].label}'
              '$horizontMetaSeparator${row.rounds ?? 0} ${tr('Runden', 'rounds')}'
              '$horizontMetaSeparator${row.wins ?? 0} ${tr('gewonnen', 'won')}'
              '$horizontMetaSeparator${row.kills ?? 0} ${tr('Abschüsse', 'kills')}'
              '$horizontMetaSeparator${_accuracy(row)} ${tr('Treffer', 'hits')}',
              style: GameType.data.copyWith(fontSize: 12),
            ),
          ),
    ];
  }

  String _accuracy(TankScoresRow row) {
    final shots = row.shots ?? 0;
    return shots == 0 ? '–' : '${(100 * (row.hits ?? 0) / shots).round()} %';
  }

  /// Earned badges out of all, opens and closes the list of them.
  Widget _badgeToggle() {
    final earned = Achievement.all
        .where((a) => progress.badges.value.contains(a.code))
        .length;
    // The count alone keeps the line short, the word comes on hover.
    return Tooltip(
      message: tr('Abzeichen', 'Badges'),
      child: InkWell(
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                HorizontSymbols.militaryTech,
                size: HzIconSize.badge,
                color: GameColors.text,
              ),
              const SizedBox(width: HzSpace.s4),
              Text(
                '$earned/${Achievement.all.length}',
                // A count beside a symbol, not a measurement.
                style: HorizontTheme.of(context).count
                    .copyWith(fontSize: 12, color: GameColors.text),
              ),
              Icon(
                _badgesOpen
                    ? HorizontSymbols.expandLess
                    : HorizontSymbols.expandMore,
                size: HzIconSize.inline,
                color: GameColors.text,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The rank as a mark: its number in mono on the sunken ground, framed by
/// the outline, radius 2 like every mark.
class RankBadge extends StatelessWidget {
  const RankBadge({required this.level, this.size = 34, super.key});

  final int level;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: GameColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HzRadius.r2),
          side: hairline,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '$level',
        style: GameType.data.copyWith(
          fontSize: size * 0.45,
          height: 1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// One badge, bright once earned and dim until then.
class BadgeChip extends StatelessWidget {
  const BadgeChip({
    required this.achievement,
    required this.earned,
    this.highlight = false,
    super.key,
  });

  final Achievement achievement;
  final bool earned;

  /// Earned just now: drawn as the selection, in the accent.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight
        ? GameColors.accentText
        : earned
        ? GameColors.text
        : GameColors.textFaint;
    return Tooltip(
      message:
          '${achievement.description}${earned ? '' : ' (${tr('noch offen', 'not yet earned')})'}',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HzSpace.s8,
          vertical: HzSpace.s4,
        ),
        decoration: ShapeDecoration(
          color: highlight ? GameColors.accentTint : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HzRadius.r2),
            side: BorderSide(color: earned ? GameColors.line : color),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              earned ? HorizontSymbols.militaryTech : HorizontSymbols.lock,
              size: HzIconSize.badge,
              color: color,
            ),
            const SizedBox(width: HzSpace.s4),
            Text(
              achievement.title.toUpperCase(),
              style: GameType.kennung.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
