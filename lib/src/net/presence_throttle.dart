import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Spaces out the presence updates of one channel. Realtime closes a
/// channel whose client tracks or untracks more than five times in 30
/// seconds, which throws the player out of the room. Updates that come
/// faster wait, and only the latest of them goes out.
class PresenceThrottle {
  PresenceThrottle(RealtimeChannel channel)
    : this.calling(
        track: (payload) => channel.track(payload),
        untrack: () => channel.untrack(),
      );

  /// Calls [track] and [untrack] instead of a channel, for the tests.
  @visibleForTesting
  PresenceThrottle.calling({
    required this._track,
    required this._untrack,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// One below the server's limit, for a little room.
  static const budget = 4;
  static const window = Duration(seconds: 30);

  final Future<Object?> Function(Map<String, dynamic> payload) _track;
  final Future<Object?> Function() _untrack;
  final DateTime Function() _now;
  final _sent = <DateTime>[];
  Map<String, dynamic>? _payload;
  var _waiting = false;
  Timer? _timer;
  var _closed = false;

  void track(Map<String, dynamic> payload) => _queue(payload);

  void untrack() => _queue(null);

  void close() {
    _closed = true;
    _timer?.cancel();
    _timer = null;
  }

  void _queue(Map<String, dynamic>? payload) {
    _payload = payload;
    _waiting = true;
    _flush();
  }

  void _flush() {
    if (_closed || !_waiting || _timer != null) {
      return;
    }
    final now = _now();
    _sent.removeWhere((at) => now.difference(at) >= window);
    if (_sent.length >= budget) {
      _timer = Timer(window - now.difference(_sent.first), () {
        _timer = null;
        _flush();
      });
      return;
    }
    _sent.add(now);
    final payload = _payload;
    _payload = null;
    _waiting = false;
    unawaited(payload == null ? _untrack() : _track(payload));
  }
}
