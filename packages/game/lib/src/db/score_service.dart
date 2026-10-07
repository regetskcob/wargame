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

  Stream<List<ScoresRow>> topScores({int limit = 20}) {
    return _client
        .table(Scores.table)
        .stream(primaryKey: [Scores.id])
        .order(Scores.wins, ascending: false)
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
  /// outlasted ([beaten], by account id) or fell before ([beatenBy]). On a
  /// database without that function the round is added up directly and
  /// null comes back.
  Future<RoundRecord?> recordRound({
    required String name,
    required RoundStats stats,
    required bool won,
    required int tankType,
    List<String> beaten = const [],
    List<String> beatenBy = const [],
  }) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'record_round',
        params: {
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
        },
      );
      final row = rows.single as Map<String, dynamic>;
      return RoundRecord(
        rating: row['rating'] as int,
        ratingChange: row['rating_change'] as int,
        xp: row['xp'] as int,
        xpGained: row['xp_gained'] as int,
      );
    } on PostgrestApiException catch (error) {
      // The function exists but refused the round, for example because it
      // came too soon after the last one: do not count it twice.
      if (error.errorCode == 'P0001') {
        return null;
      }
    } on Object {
      // Fall through to the old way below.
    }
    await _addUp(name: name, stats: stats, won: won);
    return null;
  }

  /// Adds the round to the totals without the database function. When the
  /// database has no statistics columns yet, only the win is recorded.
  Future<void> _addUp({
    required String name,
    required RoundStats stats,
    required bool won,
  }) async {
    final id = _client.auth.currentUser!.id;
    try {
      final existing = await _client
          .table(Scores.table)
          .select()
          .where(Scores.id.eq(id))
          .maybeSingle();
      await _client
          .table(Scores.table)
          .upsert(
            ScoresInsert(
              id: id,
              name: name,
              wins: (existing?.wins ?? 0) + (won ? 1 : 0),
              updatedAt: DateTime.now(),
              rounds: (existing?.rounds ?? 0) + 1,
              kills: (existing?.kills ?? 0) + stats.kills,
              damage: (existing?.damage ?? 0) + stats.damage.round(),
              shots: (existing?.shots ?? 0) + stats.shots,
              hits: (existing?.hits ?? 0) + stats.hits,
              survivalSeconds:
                  (existing?.survivalSeconds ?? 0) +
                  (stats.survived ?? 0).round(),
            ),
          );
    } on Object {
      if (won) {
        await recordWin(name: name);
      }
    }
  }

  Future<void> recordWin({required String name}) async {
    final id = _client.auth.currentUser!.id;
    final existing = await _client
        .table(Scores.table)
        .select()
        .where(Scores.id.eq(id))
        .maybeSingle();
    await _client
        .table(Scores.table)
        .upsert(
          ScoresInsert(
            id: id,
            name: name,
            wins: (existing?.wins ?? 0) + 1,
            updatedAt: DateTime.now(),
          ),
        );
  }
}
