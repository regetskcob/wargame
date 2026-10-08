// The typed table access API is still experimental.
// ignore_for_file: experimental_member_use

import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/round_stats.dart';
import 'supabase_schema.g.dart';

/// What recording a round brought: the new rating and experience and how
/// much each moved.
class RoundRecord {
  const RoundRecord({
    required this.rating,
    required this.ratingChange,
    required this.xp,
    required this.xpGained,
  });

  final int rating;
  final int ratingChange;
  final int xp;
  final int xpGained;
}

class ScoreService {
  ScoreService(this._client);

  final SupabaseClient _client;

  /// Id of the signed in player, to find their own row in the leaderboard.
  String? get myId => _client.auth.currentUser?.id;

  /// Guests play unranked: the database refuses their rounds.
  bool get isGuest => _client.auth.currentUser?.isAnonymous ?? true;

  /// The pilots with at least one round, the highest rating first. A plain
  /// query: the start page asks again every so often instead of holding a
  /// live channel open.
  Future<List<ScoresRow>> topScores({int limit = 20}) async {
    return _client
        .table(Scores.table)
        .select()
        .where(Scores.rounds.gt(0))
        .order(Scores.rating.desc())
        .order(Scores.wins.desc())
        .limit(limit);
  }

  /// Totals since Monday, the most experience first.
  Future<List<WeeklyScoresRow>> weeklyScores({int limit = 20}) async {
    try {
      return await _client
          .table(WeeklyScores.table)
          .select()
          .order(WeeklyScores.xp.desc())
          .limit(limit);
    } on Object {
      return const [];
    }
  }

  /// The pilot's totals per vehicle.
  Future<List<TankScoresRow>> myTankScores() async {
    final id = myId;
    if (id == null) {
      return const [];
    }
    try {
      return await _client
          .table(TankScores.table)
          .select()
          .where(TankScores.playerId.eq(id));
    } on Object {
      return const [];
    }
  }

  Future<ScoresRow?> myScore() async {
    final id = myId;
    if (id == null) {
      return null;
    }
    try {
      return await _client
          .table(Scores.table)
          .select()
          .where(Scores.id.eq(id))
          .maybeSingle();
    } on Object {
      return null;
    }
  }

  /// Records one finished round. The database adds it to the totals, grants
  /// experience and moves the rating against the human opponents the player
  /// outlasted ([beaten], by account id) or fell before ([beatenBy]). Null
  /// when the database refused the round.
  /// Calls `record_round`. A database without migration 0007 does not know
  /// the CPU parameters: then the round goes in without them.
  Future<List<dynamic>> _call(Map<String, dynamic> params) async {
    try {
      return await _client.rpc<List<dynamic>>('record_round', params: params);
    } on PostgrestApiException catch (error) {
      if (error.errorCode != 'PGRST202' ||
          !params.containsKey('p_cpu_beaten')) {
        rethrow;
      }
      return _client.rpc<List<dynamic>>(
        'record_round',
        params: {
          for (final entry in params.entries)
            if (!entry.key.startsWith('p_cpu_')) entry.key: entry.value,
        },
      );
    }
  }

  Future<RoundRecord?> recordRound({
    required String name,
    required RoundStats stats,
    required bool won,
    required int tankType,
    List<String> beaten = const [],
    List<String> beatenBy = const [],
    int cpuBeaten = 0,
    int cpuBeatenBy = 0,
    int cpuRating = 1000,
  }) async {
    final cpu = cpuBeaten + cpuBeatenBy > 0;
    try {
      final rows = await _call({
        if (cpu) ...{
          'p_cpu_beaten': cpuBeaten,
          'p_cpu_beaten_by': cpuBeatenBy,
          'p_cpu_rating': cpuRating,
        },
        'p_name': name,
        'p_tank': tankType,
        'p_won': won,
        'p_kills': stats.kills,
        'p_damage': stats.damage.round(),
        'p_shots': stats.shots,
        'p_hits': stats.hits,
        'p_survival': (stats.survived ?? 0).round(),
        'p_beaten': beaten,
        'p_beaten_by': beatenBy,
      });
      final row = rows.single as Map<String, dynamic>;
      return RoundRecord(
        rating: row['rating'] as int,
        ratingChange: row['rating_change'] as int,
        xp: row['xp'] as int,
        xpGained: row['xp_gained'] as int,
      );
    } on Object {
      // Refused, for example because it came too soon after the last one,
      // or the database is out of reach. Scores are only written through
      // record_round, so the round simply goes unrecorded.
      return null;
    }
  }
}
