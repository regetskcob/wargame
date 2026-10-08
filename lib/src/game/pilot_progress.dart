import 'dart:async';

import 'package:flutter/foundation.dart';

import '../db/profile_service.dart';
import '../db/score_service.dart';
import 'game_config.dart';
import 'components/tank_painter.dart';
import 'progress.dart';
import 'round_stats.dart';

/// Rank, rating and badges of the local pilot, and what the last round
/// brought. Loaded once at the start and brought up to date after every
/// round.
class PilotProgress {
  PilotProgress({required this.scores, required this.profiles});

  final ScoreService scores;
  final ProfileService profiles;

  final rank = ValueNotifier<Rank>(Rank.of(0));

  /// Null until a round against a rated opponent moved it, like the dash in
  /// the leaderboard.
  final rating = ValueNotifier<int?>(null);
  final badges = ValueNotifier<Set<String>>({});

  /// Filled in at the end of a round, cleared when the next one starts.
  final lastRecord = ValueNotifier<RoundRecord?>(null);
  final newBadges = ValueNotifier<List<Achievement>>(const []);
  final rankedUp = ValueNotifier<bool>(false);

  /// The last round went unrecorded because the pilot plays as a guest.
  final unranked = ValueNotifier<bool>(false);

  int _rounds = 0;

  /// Whether the pilot's rank allows driving [type].
  bool vehicleUnlocked(TankType type) => rank.value.level >= type.level;

  /// Whether the pilot's rank allows paint scheme [color].
  bool unlocked(int color) =>
      rank.value.level >=
      GameConfig.colorLevels[color % GameConfig.colorLevels.length];

  Future<void> load() async {
    final scoreLoad = scores.myScore();
    final badgeLoad = profiles.achievements();
    final score = await scoreLoad;
    if (score != null) {
      rank.value = Rank.of(score.xp);
      rating.value = score.ratedRounds > 0 ? score.rating : null;
      _rounds = score.rounds;
    }
    badges.value = await badgeLoad;
  }

  void clearRound() {
    lastRecord.value = null;
    newBadges.value = const [];
    rankedUp.value = false;
    unranked.value = false;
  }

  /// Records the round and hands out the badges it earned.
  Future<void> recordRound({
    required String name,
    required RoundStats stats,
    required bool won,
    required TankType tankType,
    required double hpLeft,
    required int soldiers,
    required bool night,
    required List<String> beaten,
    required List<String> beatenBy,
    int cpuBeaten = 0,
    int cpuBeatenBy = 0,
    int cpuRating = 1000,
  }) async {
    // Only accounts are ranked: no experience, rating or badges for guests.
    if (scores.isGuest) {
      unranked.value = true;
      return;
    }
    final record = await scores.recordRound(
      name: name,
      stats: stats,
      won: won,
      tankType: tankType.index,
      beaten: beaten,
      beatenBy: beatenBy,
      cpuBeaten: cpuBeaten,
      cpuBeatenBy: cpuBeatenBy,
      cpuRating: cpuRating,
    );
    // A refused round earns no badges either: the database only takes
    // badges right after a recorded round.
    if (record == null) {
      return;
    }
    _rounds++;
    final before = rank.value.level;
    rank.value = Rank.of(record.xp);
    if (rating.value != null || record.ratingChange != 0) {
      rating.value = record.rating;
    } else {
      // A rated round can leave the rating where it was: ask whether this
      // one counted.
      final score = await scores.myScore();
      if (score != null && score.ratedRounds > 0) {
        rating.value = score.rating;
      }
    }
    rankedUp.value = rank.value.level > before;
    lastRecord.value = record;
    final tanksWithWins = <TankType>{
      if (won) tankType,
      for (final row in await scores.myTankScores())
        if ((row.wins ?? 0) > 0 && row.tankType != null)
          TankType.values[row.tankType! % TankType.values.length],
    };
    final earned = Achievement.newlyEarned(
      RoundContext(
        stats: stats,
        won: won,
        hpLeft: hpLeft,
        soldiers: soldiers,
        night: night,
        tankType: tankType,
        totalRounds: _rounds,
        tanksWithWins: tanksWithWins,
      ),
      badges.value,
    );
    if (earned.isEmpty) {
      return;
    }
    badges.value = {...badges.value, for (final a in earned) a.code};
    newBadges.value = earned;
    unawaited(profiles.unlock(earned.map((a) => a.code)));
  }
}
