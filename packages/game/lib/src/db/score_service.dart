// The typed table access API is still experimental.
// ignore_for_file: experimental_member_use

import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/round_stats.dart';
import 'supabase_schema.g.dart';

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

  /// Adds one finished round to the totals of the player. When the database
  /// has no statistics columns yet, only the win is recorded.
  Future<void> recordRound({
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
