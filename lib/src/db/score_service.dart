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

  /// The pilots with at least one round, the most experienced first. The
  /// leaderboard ranks them by points (`score_points.dart`), which grow with
  /// experience, so the top by experience holds the top by points. A plain
  /// query: the start page asks again every so often instead of holding a
  /// live channel open.
  Future<List<ScoresRow>> topScores({int limit = 20}) async {
    return _client
        .table(Scores.table)
        .select()
        .where(Scores.rounds.gt(0))
        .order(Scores.xp.desc())
        .order(Scores.wins.desc())
        .limit(limit);
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

  /// Takes the server's ticket for a round that starts now, with [cpu] CPU
  /// tanks in it (migration 0019). `record_round` measures the round by the
  /// server's clock from this moment and takes every ticket once; a round
  /// without one counts with much tighter limits and nothing for CPU tanks.
  /// Null when there is none: a guest, no server, a database without the
  /// migration.
  Future<String?> startRound({int cpu = 0}) async {
    try {
      return await _client
          .rpc<String?>('start_round', params: {'p_cpu': cpu})
          // The round goes on without it; only the recording waits.
          .timeout(const Duration(seconds: 10));
    } on Object {
      return null;
    }
  }

  /// The parameters of `record_round` for one round, as [recordRound]
  /// sends them, with the [ticket] from [startRound] if there was one.
  static Map<String, dynamic> roundParams({
    required String name,
    required RoundStats stats,
    required bool won,
    required int tankType,
    List<String> beaten = const [],
    List<String> beatenBy = const [],
    int cpuBeaten = 0,
    int cpuBeatenBy = 0,
    int cpuRating = 1000,
    String? ticket,
    int waves = 0,
    bool wavesBaseFell = false,
  }) => {
    'p_ticket': ?ticket,
    // Only a defense round sends its waves (migration 0022).
    if (waves > 0) ...{'p_waves': waves, 'p_waves_base_fell': wavesBaseFell},
    if (cpuBeaten + cpuBeatenBy > 0) ...{
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
  };

  /// Sends a round built by [roundParams]. Throws when the database refuses
  /// it or cannot be reached.
  Future<RoundRecord> submit(Map<String, dynamic> params) async {
    final rows = await _call(params);
    final row = rows.single as Map<String, dynamic>;
    return RoundRecord(
      rating: row['rating'] as int,
      ratingChange: row['rating_change'] as int,
      xp: row['xp'] as int,
      xpGained: row['xp_gained'] as int,
    );
  }

  /// Records one finished round. The database adds it to the totals, grants
  /// experience and moves the rating against the human opponents the player
  /// outlasted ([beaten], by account id) or fell before ([beatenBy]). Null
  /// when the database refused the round.
  /// Calls `record_round`. A database without migration 0022 does not know
  /// the waves, one without 0019 the ticket, one without 0007 the CPU
  /// parameters: then the round goes in without them.
  Future<List<dynamic>> _call(Map<String, dynamic> params) async {
    try {
      return await _client.rpc<List<dynamic>>('record_round', params: params);
    } on PostgrestApiException catch (error) {
      if (error.errorCode != 'PGRST202') {
        rethrow;
      }
      // The parameters of the newest migration go first.
      final newest = ['p_waves', 'p_ticket', 'p_cpu_']
          .where((prefix) => params.keys.any((k) => k.startsWith(prefix)))
          .firstOrNull;
      if (newest == null) {
        rethrow;
      }
      return _call({
        for (final entry in params.entries)
          if (!entry.key.startsWith(newest)) entry.key: entry.value,
      });
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
    String? ticket,
    int waves = 0,
    bool wavesBaseFell = false,
  }) async {
    try {
      return await submit(
        roundParams(
          name: name,
          stats: stats,
          won: won,
          tankType: tankType,
          beaten: beaten,
          beatenBy: beatenBy,
          cpuBeaten: cpuBeaten,
          cpuBeatenBy: cpuBeatenBy,
          cpuRating: cpuRating,
          ticket: ticket,
          waves: waves,
          wavesBaseFell: wavesBaseFell,
        ),
      );
    } on Object {
      // Refused, for example because it came too soon after the last one,
      // or the database is out of reach. Scores are only written through
      // record_round, so the round simply goes unrecorded.
      return null;
    }
  }
}
