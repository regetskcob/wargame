import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tells the database once a minute that this game is running, so the home
/// screen widget can count the pilots online. Pauses while the app sits in
/// the background. Every call fails quietly, so the game keeps working
/// against a database without migration 0011.
class OnlineService {
  OnlineService(this._client, {required this.inMatch});

  final SupabaseClient _client;

  /// Whether the pilot is in a round right now, asked on every heartbeat.
  final bool Function() inMatch;

  static const interval = Duration(seconds: 60);

  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  void start() {
    _lifecycle = AppLifecycleListener(
      onResume: _resume,
      onPause: _pause,
      onDetach: _pause,
    );
    _resume();
  }

  void _resume() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(ping()));
    unawaited(ping());
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> ping() async {
    if (_client.auth.currentUser == null) {
      return;
    }
    try {
      await _client.rpc<void>('ping_online', params: {'p_in_match': inMatch()});
    } on Object {
      return;
    }
  }

  void dispose() {
    _pause();
    _lifecycle?.dispose();
    _lifecycle = null;
  }
}
