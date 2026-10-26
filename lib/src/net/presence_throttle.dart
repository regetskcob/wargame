import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Spaces out the presence updates of one channel. Realtime closes a
/// channel whose client tracks or untracks more than five times in 30
/// seconds, which throws the player out of the room. Updates that come
/// faster wait, and only the latest of them goes out.
///
/// What went out is kept per channel topic, not per throttle: a rejoin
/// builds a new channel and a new throttle, and its first track came on top
/// of the ones just before the drop, which once went over the limit
/// (`ClientPresenceRateLimitReached` on 22 October 2026).
class PresenceThrottle {
  /// [topic] is the name the channel was opened with.
  PresenceThrottle(RealtimeChannel channel, String topic)
    : this.calling(
        track: (payload) => channel.track(payload),
        untrack: () => channel.untrack(),
        topic: topic,
      );

  /// Calls [track] and [untrack] instead of a channel, for the tests. With
  /// a [topic], throttles of the same topic share what went out.
  @visibleForTesting
  PresenceThrottle.calling({
    required this._track,
    required this._untrack,
    DateTime Function()? now,
    String? topic,
  }) : _now = now ?? DateTime.now,
       _sent = topic == null
           ? <DateTime>[]
           : _sentByTopic.putIfAbsent(topic, () => <DateTime>[]);

  /// When each topic last tracked or untracked, across rejoins.
  static final _sentByTopic = <String, List<DateTime>>{};

  /// Forgets every topic, so tests start from nothing.
  @visibleForTesting
  static void forgetAll() => _sentByTopic.clear();

  /// One below the server's limit, for a little room.
  static const budget = 4;
  static const window = Duration(seconds: 30);

  final Future<Object?> Function(Map<String, dynamic> payload) _track;
  final Future<Object?> Function() _untrack;
  final DateTime Function() _now;
  final List<DateTime> _sent;
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
