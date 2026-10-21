import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../../game/kill_feed.dart';
import '../../game/game_config.dart';
import '../theme.dart';
import '../../l10n/l10n.dart';

/// The last few kills, newest at the bottom, fading out after a few seconds.
class KillFeedView extends StatefulWidget {
  const KillFeedView({required this.feed, this.compact = false, super.key});

  final ValueListenable<List<KillEntry>> feed;

  /// Fewer and smaller lines for phones held sideways.
  final bool compact;

  @override
  State<KillFeedView> createState() => _KillFeedViewState();
}

class _KillFeedViewState extends State<KillFeedView> {
  static const _lifetime = Duration(seconds: 8);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
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

  Color _teamColor(int team, {required Color fallback}) =>
      team > 0 ? GameConfig.teamColors[team] : fallback;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<List<KillEntry>>(
        valueListenable: widget.feed,
        builder: (context, entries, _) {
          final now = DateTime.now();
          var live = [
            for (final e in entries)
              if (now.difference(e.at) < _lifetime) e,
          ];
          if (widget.compact && live.length > 2) {
            live = live.sublist(live.length - 2);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [for (final entry in live) _row(entry, now)],
          );
        },
      ),
    );
  }

  Widget _row(KillEntry entry, DateTime now) {
    final age = now.difference(entry.at).inMilliseconds;
    final fade = age > 6000 ? (1 - (age - 6000) / 2000).clamp(0.0, 1.0) : 1.0;
    final text = (widget.compact ? GameType.caption : GameType.label).copyWith(
      fontWeight: FontWeight.w700,
      color: GameColors.text,
    );
    // Quiet rows on the sunken ground: only the kills that concern the
    // player take a line, the accent for "you shot" and critical for
    // "you were hit"; the player's own name says which one it is.
    final edge = entry.byMe
        ? GameColors.accentText
        : entry.meDied
        ? GameColors.critical
        : null;
    return Opacity(
      opacity: fade,
      child: Container(
        margin: EdgeInsets.only(top: widget.compact ? HzSpace.s2 : HzSpace.s4),
        padding: widget.compact
            ? const EdgeInsets.symmetric(
                horizontal: HzSpace.s8,
                vertical: HzSpace.s2,
              )
            : const EdgeInsets.symmetric(
                horizontal: HzSpace.s8,
                vertical: HzSpace.s4,
              ),
        decoration: ShapeDecoration(
          color: GameColors.sunken.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HzRadius.r6),
            side: edge == null
                ? BorderSide.none
                : BorderSide(color: edge, width: HzLine.hairline),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.killer != null) ...[
              Flexible(
                child: Text(
                  entry.killer!,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: text.copyWith(
                    color: _teamColor(
                      entry.killerTeam,
                      fallback: GameColors.text,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: HzSpace.s8),
              const Icon(
                HorizontSymbols.gpsFixed,
                size: HzIconSize.badge,
                color: GameColors.textMuted,
              ),
              const SizedBox(width: HzSpace.s8),
            ],
            // In a narrow column a long name fades out rather than
            // pushing the row past the edge.
            Flexible(
              child: Text(
                entry.victim,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: text.copyWith(
                  color: _teamColor(
                    entry.victimTeam,
                    fallback: GameColors.text,
                  ),
                  decoration: TextDecoration.lineThrough,
                  decorationColor: GameColors.textMuted,
                ),
              ),
            ),
            if (entry.killer == null) ...[
              const SizedBox(width: HzSpace.s8),
              Text(
                // No shooter: the zone, a mine or a lost connection, so
                // not "dropped out", which read as a connection lost.
                tr('ist ausgeschieden', 'is out'),
                style: GameType.caption,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
