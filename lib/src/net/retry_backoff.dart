import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// How long to wait before joining a dropped channel again: 2 seconds
/// first, twice as long after every further failure, at most [max]. A
/// channel that stays down for good (the project over its message limit,
/// the device offline) then asks twice a minute instead of every two
/// seconds, which would only add to the load that closed it. A channel that
/// came up again and stayed up for [stableAfter] starts over at the short
/// wait.
class RetryBackoff {
  RetryBackoff({
    this.first = const Duration(seconds: 2),
    this.max = const Duration(seconds: 30),
    this.stableAfter = const Duration(seconds: 10),
  });

  final Duration first;
  final Duration max;

  /// How long a channel has to stay up to count as back. Above the
  /// project's message limit Realtime lets every join through and closes
  /// it again at once (measured on a local stack): starting over on the
  /// join itself rejoined every 2 seconds for as long as a flood lasted.
  final Duration stableAfter;
  var _failures = 0;
  Timer? _stable;

  /// Failures in a row since the channel last came up.
  int get failures => _failures;

  /// The wait before the next attempt, counting this failure.
  Duration next() {
    _stable?.cancel();
    _stable = null;
    final factor = 1 << min(_failures, 16);
    _failures++;
    final wait = first * factor;
    return wait > max ? max : wait;
  }

  /// The channel is up again: once it stays up, the next drop waits as
  /// briefly as the first.
  void up() {
    _stable?.cancel();
    _stable = Timer(stableAfter, reset);
  }

  /// Starts over at the short wait, as after leaving the room.
  void reset() {
    _stable?.cancel();
    _stable = null;
    _failures = 0;
  }
}

/// Starts [future] without waiting for it, and logs instead of losing it
/// when it fails. For sends and channel housekeeping whose failure the
/// game rides out (the next state message, the next reconnect), but which
/// should still show up when debugging.
void fireAndForget(Future<void> future, String what) {
  unawaited(
    future.catchError((Object error) {
      debugPrint('$what failed: $error');
    }),
  );
}
