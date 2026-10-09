import 'package:flutter/material.dart';

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
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              tr(
                'Als Gast wird nicht gewertet. Mit einem Konto sammelst du '
                    'EP, Wertung und Abzeichen und schaltest Fahrzeuge frei.',
                'Guests are not ranked. With an account you collect XP, '
                    'rating and badges and unlock vehicles.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: GameColors.textDim, fontSize: 13),
            ),
          );
        }
        if (record == null && badges.isEmpty) {
          return const SizedBox();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (record != null) _numbers(record),
              if (progress.rankedUp.value) ...[
                const SizedBox(height: 8),
                _promotion(progress.rank.value),
              ],
              if (badges.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
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
    final changeColor = change > 0
        ? const Color(0xFF9CCC65)
        : change < 0
        ? GameColors.danger
        : GameColors.textDim;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 18,
      children: [
        Text(
          '+${record.xpGained} ${tr('EP', 'XP')}',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: GameColors.amber,
          ),
        ),
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
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ],
    );
  }

  Widget _promotion(Rank rank) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RankBadge(level: rank.level, size: 26),
        const SizedBox(width: 8),
        Text(
          tr(
            'BEFÖRDERT ZUM ${rank.title.toUpperCase()}',
            'PROMOTED TO ${rank.title.toUpperCase()}',
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: GameColors.amber,
          ),
        ),
      ],
    );
  }
}
