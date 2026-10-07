import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../game/kill_feed.dart';
import '../../game_config.dart';
import '../../theme.dart';

/// The last few kills, newest at the bottom, fading out after a few seconds.
class KillFeedView extends StatefulWidget {
  const KillFeedView({required this.feed, super.key});

  final ValueListenable<List<KillEntry>> feed;

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
          final live = [
            for (final e in entries)
              if (now.difference(e.at) < _lifetime) e,
          ];
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
    const text = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
    return Opacity(
      opacity: fade,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: ShapeDecoration(
          color: const Color(0xB3101408),
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: BorderSide(
              color: entry.byMe
                  ? BwColors.amber
                  : entry.meDied
                  ? BwColors.danger
                  : BwColors.oliveLight.withValues(alpha: 0.6),
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
                  color: _teamColor(entry.killerTeam, fallback: BwColors.text),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.gps_fixed, size: 14, color: BwColors.amber),
              const SizedBox(width: 8),
            ],
            Text(
              entry.victim,
              style: text.copyWith(
                color: _teamColor(entry.victimTeam, fallback: BwColors.text),
                decoration: TextDecoration.lineThrough,
                decorationColor: BwColors.textDim,
              ),
            ),
            if (entry.killer == null) ...[
              const SizedBox(width: 8),
              const Text(
                'ist ausgefallen',
                style: TextStyle(fontSize: 12, color: BwColors.textDim),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
