import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// How long to wait before joining a dropped channel again: 2 seconds
/// first, twice as long after every further failure, at most [max]. A
/// channel that stays down for good (the project over its message limit,
/// the device offline) then asks twice a minute instead of every two
/// seconds, which would only add to the load that closed it. A channel that
/// came up again starts over at the short wait.
class RetryBackoff {
  RetryBackoff({
    this.first = const Duration(seconds: 2),
    this.max = const Duration(seconds: 30),
  });

  final Duration first;
  final Duration max;
  var _failures = 0;

  /// Failures in a row since the channel last came up.
  int get failures => _failures;

  /// The wait before the next attempt, counting this failure.
  Duration next() {
    final factor = 1 << min(_failures, 16);
    _failures++;
    final wait = first * factor;
    return wait > max ? max : wait;
  }

  /// The channel is up again.
  void reset() => _failures = 0;
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
