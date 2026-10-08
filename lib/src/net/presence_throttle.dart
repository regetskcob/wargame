import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Spaces out the presence updates of one channel. Realtime closes a
/// channel whose client tracks or untracks more than five times in 30
/// seconds, which throws the player out of the room. Updates that come
/// faster wait, and only the latest of them goes out.
class PresenceThrottle {
  PresenceThrottle(this._channel);

  /// One below the server's limit, for a little room.
  static const _budget = 4;
  static const _window = Duration(seconds: 30);

  final RealtimeChannel _channel;
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
    final now = DateTime.now();
    _sent.removeWhere((at) => now.difference(at) >= _window);
    if (_sent.length >= _budget) {
      _timer = Timer(_window - now.difference(_sent.first), () {
        _timer = null;
        _flush();
      });
      return;
    }
    _sent.add(now);
    final payload = _payload;
    _payload = null;
    _waiting = false;
    unawaited(payload == null ? _channel.untrack() : _channel.track(payload));
  }
}
