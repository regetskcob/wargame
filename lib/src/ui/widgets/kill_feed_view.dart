import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
    final highlight = entry.byMe || entry.meDied;
    final text = TextStyle(
      fontSize: widget.compact ? 11 : 13,
      fontWeight: FontWeight.w700,
    );
    return Opacity(
      opacity: fade,
      child: Container(
        margin: EdgeInsets.only(top: widget.compact ? 2 : 4),
        padding: widget.compact
            ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
            : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: ShapeDecoration(
          color: const Color(0xB3101408),
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(
              color: entry.byMe
                  ? GameColors.amber
                  : entry.meDied
                  ? GameColors.danger
                  : GameColors.oliveLight.withValues(alpha: 0.6),
              width: highlight ? 1.6 : 1,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.killer != null) ...[
              Text(
                entry.killer!,
                style: text.copyWith(
                  color: _teamColor(
                    entry.killerTeam,
                    fallback: GameColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.gps_fixed, size: 14, color: GameColors.amber),
              const SizedBox(width: 8),
            ],
            Text(
              entry.victim,
              style: text.copyWith(
                color: _teamColor(entry.victimTeam, fallback: GameColors.text),
                decoration: TextDecoration.lineThrough,
                decorationColor: GameColors.textDim,
              ),
            ),
            if (entry.killer == null) ...[
              const SizedBox(width: 8),
              Text(
                tr('ist ausgefallen', 'dropped out'),
                style: const TextStyle(fontSize: 12, color: GameColors.textDim),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
