import 'package:flutter/material.dart';

import '../../game/pilot_progress.dart';
import '../../game/progress.dart';
import '../theme.dart';
import '../../l10n/l10n.dart';

/// Rank with the way to the next one and the rating in one line. The
/// badges fold out on demand. Drawn as a quiet dark box without a frame, so
/// it reads as status and does not compete with the framed mode buttons.
class PilotCard extends StatefulWidget {
  const PilotCard({required this.progress, super.key});

  final PilotProgress progress;

  @override
  State<PilotCard> createState() => _PilotCardState();
}

class _PilotCardState extends State<PilotCard> {
  var _badgesOpen = false;

  PilotProgress get progress => widget.progress;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        progress.rank,
        progress.rating,
        progress.badges,
      ]),
      builder: (context, _) {
        final rank = progress.rank.value;
        final rating = progress.rating.value;
        return Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          decoration: BoxDecoration(
            color: const Color(0x55000000),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  RankBadge(level: rank.level, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${rank.title.toUpperCase()} · ${tr('STUFE', 'LEVEL')} ${rank.level}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: GameColors.textDim,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: rank.progress,
                            minHeight: 4,
                            backgroundColor: const Color(0x33FFFFFF),
                            color: GameColors.amber,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${rank.xp} / ${rank.next} ${tr('EP', 'XP')}',
                                maxLines: 1,
                                softWrap: false,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: GameColors.textDim,
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: GameColors.sand,
                        ),
                      ),
                      Text(
                        tr('WERTUNG', 'RATING'),
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.4,
                          color: GameColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_badgesOpen) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
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
              ],
            ],
          ),
        );
      },
    );
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
        onTap: () => setState(() => _badgesOpen = !_badgesOpen),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.military_tech, size: 14, color: GameColors.sand),
              const SizedBox(width: 3),
              Text(
                '$earned/${Achievement.all.length}',
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: GameColors.sand,
                ),
              ),
              Icon(
                _badgesOpen ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: GameColors.sand,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chevrons for the rank, more of them the higher it is.
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
        color: GameColors.olive,
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(size / 5),
          side: const BorderSide(color: GameColors.amber, width: 1.5),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '$level',
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w900,
          color: GameColors.text,
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

  /// Earned just now: drawn in amber.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight
        ? GameColors.amber
        : earned
        ? GameColors.sand
        : const Color(0x559DA58A);
    return Tooltip(
      message:
          '${achievement.description}${earned ? '' : ' (${tr('noch offen', 'not yet earned')})'}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: ShapeDecoration(
          color: highlight ? const Color(0x33FFB300) : null,
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: color),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              earned ? Icons.military_tech : Icons.lock_outline,
              size: 13,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              achievement.title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
