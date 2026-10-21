import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../../db/score_service.dart';
import '../../game/pilot_progress.dart';
import '../../game/progress.dart';
import '../theme.dart';
import 'pilot_card.dart';
import '../../l10n/l10n.dart';

/// What the round brought: experience, the change in rating, a promotion and
/// new badges. Appears once the database has answered.
class RoundRewards extends StatelessWidget {
  const RoundRewards({required this.progress, super.key});

  final PilotProgress progress;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        progress.lastRecord,
        progress.newBadges,
        progress.rankedUp,
        progress.unranked,
      ]),
      builder: (context, _) {
        final record = progress.lastRecord.value;
        final badges = progress.newBadges.value;
        if (progress.unranked.value) {
          return Padding(
            padding: const EdgeInsets.only(top: HzSpace.s16),
            child: Text(
              tr(
                'Als Gast wird nicht gewertet. Mit einem Konto sammelst du '
                    'EP, Wertung und Abzeichen und schaltest Fahrzeuge frei.',
                'Guests are not ranked. With an account you collect XP, '
                    'rating and badges and unlock vehicles.',
              ),
              textAlign: TextAlign.center,
              style: GameType.callout.copyWith(color: GameColors.textMuted),
            ),
          );
        }
        if (record == null && badges.isEmpty) {
          return const SizedBox();
        }
        return Padding(
          padding: const EdgeInsets.only(top: HzSpace.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (record != null) _numbers(record),
              if (progress.rankedUp.value) ...[
                const SizedBox(height: HzSpace.s8),
                _promotion(progress.rank.value),
              ],
              if (badges.isNotEmpty) ...[
                const SizedBox(height: HzSpace.s12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: HzSpace.s8,
                  runSpacing: HzSpace.s8,
                  children: [
                    for (final badge in badges)
                      BadgeChip(
                        achievement: badge,
                        earned: true,
                        highlight: true,
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _numbers(RoundRecord record) {
    final change = record.ratingChange;
    // The sign of the number says the direction, the colour repeats it.
    final changeColor = change > 0
        ? GameColors.positive
        : change < 0
        ? GameColors.critical
        : GameColors.textMuted;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: HzSpace.s16,
      children: [
        Text(
          '+${record.xpGained} ${tr('EP', 'XP')}',
          style: GameType.data.copyWith(fontWeight: FontWeight.w600),
        ),
        // The rating weighs who outlasted whom. A defense round has no such
        // order and always left it unchanged, which read like a "+0" penalty.
        if (change != 0)
          Text.rich(
            TextSpan(
              text: '${tr('WERTUNG', 'RATING')} ${record.rating} ',
              children: [
                TextSpan(
                  text: '(${change >= 0 ? '+' : ''}$change)',
                  style: TextStyle(color: changeColor),
                ),
              ],
            ),
            style: GameType.data.copyWith(fontWeight: FontWeight.w600),
          ),
      ],
    );
  }

  Widget _promotion(Rank rank) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RankBadge(level: rank.level, size: 26),
        const SizedBox(width: HzSpace.s8),
        Flexible(
          child: Text(
            tr(
              'BEFÖRDERT ZUM ${rank.title.toUpperCase()}',
              'PROMOTED TO ${rank.title.toUpperCase()}',
            ),
            style: GameType.title,
          ),
        ),
      ],
    );
  }
}
