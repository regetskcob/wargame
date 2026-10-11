import 'package:clock/clock.dart';

import 'net_events.dart';

/// Caps how many messages of one kind a room's channel lets through, per
/// sender and in all. Anybody with the public key can broadcast into any
/// room, and every message runs game code on every receiver: a flood of
/// shots, blasts or tanks would make all of them stutter. Honest games stay
/// far below these limits (a tank sends ten states a second, a whole room
/// of four with CPU tanks about 250 messages a second, see
/// `GameConfig.roomLoad`), so only floods are cut.
class InboundLimiter {
  /// Messages a second one sender may send of one kind, and how many may
  /// come at once (a salvo of soldiers falling to one blast).
  static const perSender = 40.0;
  static const senderBurst = 80.0;

  /// Messages a second of one kind from everybody together.
  static const perEvent = 300.0;
  static const eventBurst = 600.0;

  /// Kinds that come seldom in a real game, with a tighter cap for all
  /// senders together: each of them adds soldiers, starts a round or ends
  /// one on every receiver.
  static const rare = <NetEvent, double>{
    NetEvent.squad: 10,
    NetEvent.roundStart: 4,
    NetEvent.close: 4,
    NetEvent.troops: 10,
    NetEvent.tower: 80,
    NetEvent.defense: 60,
    NetEvent.flag: 30,
    // A squad is ordered at most every 2.5 seconds.
    NetEvent.squadOrder: 30,
  };

  /// Senders remembered; a flood of made up ids does not grow the map
  /// without end.
  static const maxSenders = 512;

  final _senders = <String, _Bucket>{};
  final _events = <NetEvent, _Bucket>{};

  /// Whether a message of [event] from [sender] may pass, counting it.
  bool admit(NetEvent event, String? sender) {
    final now = clock.now().microsecondsSinceEpoch / 1e6;
    final key = '${event.index}|${sender ?? ''}';
    var one = _senders[key];
    if (one == null) {
      if (_senders.length >= maxSenders) {
        // Full buckets are senders that have been quiet a while.
        _senders.removeWhere(
          (_, bucket) =>
              bucket.level(now, perSender, senderBurst) >= senderBurst,
        );
        if (_senders.length >= maxSenders) {
          _senders.clear();
        }
      }
      one = _senders[key] = _Bucket(senderBurst, now);
    }
    if (!one.take(now, rate: perSender, burst: senderBurst)) {
      return false;
    }
    // Only what one sender may send counts against everybody's cap, so one
    // flooding sender does not starve the others.
    final rate = rare[event] ?? perEvent;
    final burst = rare.containsKey(event) ? rate * 2 : eventBurst;
    final all = _events.putIfAbsent(event, () => _Bucket(burst, now));
    return all.take(now, rate: rate, burst: burst);
  }
}

/// A token bucket: fills at a rate up to its burst, each message takes one.
class _Bucket {
  _Bucket(this._tokens, this._at);

  double _tokens;
  double _at;

  double level(double now, double rate, double burst) {
    final filled = _tokens + (now - _at) * rate;
    return filled > burst ? burst : filled;
  }

  bool take(double now, {required double rate, required double burst}) {
    _tokens = level(now, rate, burst);
    _at = now;
    if (_tokens < 1) {
      return false;
    }
    _tokens -= 1;
    return true;
  }
}
