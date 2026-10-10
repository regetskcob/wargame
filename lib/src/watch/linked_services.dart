import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/env.dart';
import '../db/profile_service.dart';
import '../db/score_service.dart';
import '../game/round_stats.dart';
import 'account_link.dart';

/// A connection for the watch that speaks as the phone's account while one
/// is linked ([AccountLink]), else as the watch's own guest.
SupabaseClient linkedClient(AccountLink link, SupabaseClient own) =>
    SupabaseClient(
      Env.supabaseUrl,
      Env.supabaseKey,
      // Signs nobody in: the session is the phone's or the watch's own.
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
      accessToken: () async =>
          link.account.value?.token ?? own.auth.currentSession?.accessToken,
    );

/// The profile of the phone's account on the watch, or of the guest.
class LinkedProfiles extends ProfileService {
  LinkedProfiles(this.link, this.own, SupabaseClient client) : super(client);

  final AccountLink link;
  final SupabaseClient own;

  @override
  String? get uid => link.account.value?.userId ?? own.auth.currentUser?.id;
}

/// Rounds on the watch count for the phone's account. A round that ends
/// while the phone's token has run out waits in [pending] until a fresh one
/// comes.
class LinkedScores extends ScoreService {
  LinkedScores(this.link, this.own, SupabaseClient client, {this.pending})
    : super(client) {
    link.account.addListener(_flushSoon);
  }

  final AccountLink link;
  final SupabaseClient own;
  final PendingRounds? pending;

  @override
  String? get myId => link.account.value?.userId ?? own.auth.currentUser?.id;

  @override
  bool get isGuest => link.account.value == null;

  @override
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
    final params = ScoreService.roundParams(
      name: name,
      stats: stats,
      won: won,
      tankType: tankType,
      beaten: beaten,
      beatenBy: beatenBy,
      cpuBeaten: cpuBeaten,
      cpuBeatenBy: cpuBeatenBy,
      cpuRating: cpuRating,
    );
    final usable =
        (link.account.value?.usable ?? false) || await link.refresh();
    if (!usable) {
      await pending?.add(params);
      return null;
    }
    try {
      return await submit(params);
    } on PostgrestApiException {
      // Refused by the database, as too soon after the last round: trying
      // again later would be refused just the same.
      return null;
    } on Object {
      // Out of reach: it goes in later.
      await pending?.add(params);
      return null;
    }
  }

  bool _flushing = false;

  void _flushSoon() => unawaited(flush());

  /// Sends the rounds that waited, one at a time with the gap the database
  /// asks for between two rounds.
  Future<void> flush({Duration gap = const Duration(seconds: 9)}) async {
    final queue = pending;
    if (queue == null || _flushing) {
      return;
    }
    _flushing = true;
    try {
      while (link.account.value?.usable ?? false) {
        final next = await queue.first();
        if (next == null) {
          return;
        }
        try {
          await submit(next);
        } on PostgrestApiException {
          // Refused: drop it rather than try for ever.
        } on Object {
          return;
        }
        await queue.removeFirst();
        await Future<void>.delayed(gap);
      }
    } finally {
      _flushing = false;
    }
  }
}

/// Rounds the watch finished for the phone's account that are not in yet.
class PendingRounds {
  PendingRounds({SharedPreferencesAsync? store})
    : _store = store ?? SharedPreferencesAsync();

  static const _key = 'panzergefecht.pendingRounds';

  /// The database takes 60 rounds an hour; more than that waiting would be
  /// refused anyway.
  static const limit = 30;

  final SharedPreferencesAsync _store;

  Future<List<Map<String, dynamic>>> _all() async {
    try {
      final text = await _store.getString(_key);
      final list = text == null ? const [] : jsonDecode(text) as List;
      return [for (final item in list) Map<String, dynamic>.from(item as Map)];
    } on Object {
      return [];
    }
  }

  Future<void> _write(List<Map<String, dynamic>> rounds) async {
    try {
      await _store.setString(_key, jsonEncode(rounds));
    } on Object {
      // Then they only wait until the watch app closes.
    }
  }

  Future<void> add(Map<String, dynamic> params) async {
    final rounds = await _all();
    rounds.add(params);
    await _write(
      rounds.length > limit ? rounds.sublist(rounds.length - limit) : rounds,
    );
  }

  Future<Map<String, dynamic>?> first() async {
    final rounds = await _all();
    return rounds.isEmpty ? null : rounds.first;
  }

  Future<void> removeFirst() async {
    final rounds = await _all();
    if (rounds.isNotEmpty) {
      await _write(rounds.sublist(1));
    }
  }

  @visibleForTesting
  Future<int> get length async => (await _all()).length;
}
