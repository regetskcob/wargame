// The typed table access API is still experimental.
// ignore_for_file: experimental_member_use

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_schema.g.dart';

/// Call sign, look and badges of the signed in pilot. Every call fails
/// quietly, so the game keeps working against a database that lacks the
/// newer tables.
class ProfileService {
  ProfileService(this._client);

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  Future<PlayersRow?> load() async {
    final uid = _uid;
    if (uid == null) {
      return null;
    }
    try {
      return await _client
          .table(Players.table)
          .select()
          .where(Players.id.eq(uid))
          .maybeSingle();
    } on Object {
      return null;
    }
  }

  Future<void> save({required String name, required int style}) async {
    final uid = _uid;
    if (uid == null) {
      return;
    }
    try {
      await _client
          .table(Players.table)
          .upsert(
            PlayersInsert(
              id: uid,
              name: name,
              style: style,
              updatedAt: DateTime.now(),
            ),
          );
    } on Object {
      // Older database without the style column: keep at least the name.
      try {
        await _client
            .table(Players.table)
            .upsert(PlayersInsert(id: uid, name: name));
      } on Object {
        return;
      }
    }
  }

  /// Codes of the badges the pilot has earned.
  Future<Set<String>> achievements() async {
    final uid = _uid;
    if (uid == null) {
      return {};
    }
    try {
      final rows = await _client
          .table(Achievements.table)
          .select()
          .where(Achievements.playerId.eq(uid));
      return {for (final row in rows) row.code};
    } on Object {
      return {};
    }
  }

  Future<void> unlock(Iterable<String> codes) async {
    final uid = _uid;
    if (uid == null || codes.isEmpty) {
      return;
    }
    try {
      await _client.table(Achievements.table).upsertAll([
        for (final code in codes) AchievementsInsert(playerId: uid, code: code),
      ], ignoreDuplicates: true);
    } on Object {
      return;
    }
  }
}
