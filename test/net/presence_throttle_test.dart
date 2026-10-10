import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/net/presence_throttle.dart';

/// Realtime closes a channel whose client tracks or untracks more than five
/// times in 30 seconds (supabase/realtime, presence_handler.ex). The throttle
/// has to keep every client below that, whatever the game asks for.
const _serverLimit = 5;
const _serverWindow = Duration(seconds: 30);

class _Call {
  _Call(this.at, this.payload);

  final Duration at;

  /// Null for an untrack.
  final Map<String, dynamic>? payload;
}

/// Runs [body] against a throttle on a fake clock and hands back every call
/// that reached the channel.
List<_Call> _run(
  void Function(PresenceThrottle throttle, FakeAsync async) body, {
  Duration settle = const Duration(minutes: 2),
}) {
  final calls = <_Call>[];
  fakeAsync((async) {
    final start = DateTime.utc(2026, 10, 8);
    final clock = async.getClock(start);
    final throttle = PresenceThrottle.calling(
      track: (payload) async =>
          calls.add(_Call(clock.now().difference(start), payload)),
      untrack: () async =>
          calls.add(_Call(clock.now().difference(start), null)),
      now: clock.now,
    );
    body(throttle, async);
    async.elapse(settle);
  });
  return calls;
}

/// The most calls that fell into any 30 second window.
int _busiestWindow(List<_Call> calls) {
  var most = 0;
  for (final first in calls) {
    final inWindow = calls
        .where((c) => c.at >= first.at && c.at - first.at < _serverWindow)
        .length;
    if (inWindow > most) {
      most = inWindow;
    }
  }
  return most;
}

void main() {
  test('a single update goes out at once', () {
    final calls = _run((throttle, async) {
      throttle.track({'phase': 'lobby'});
      async.flushMicrotasks();
    }, settle: Duration.zero);
    expect(calls, hasLength(1));
    expect(calls.single.at, Duration.zero);
  });

  test('tapping through the tank colours never trips the server limit, '
      'and the last colour arrives', () {
    final calls = _run((throttle, async) {
      // Twenty taps, a fifth of a second apart.
      for (var colour = 0; colour < 20; colour++) {
        throttle.track({'color': colour});
        async.elapse(const Duration(milliseconds: 200));
      }
    });
    expect(_busiestWindow(calls), lessThan(_serverLimit));
    expect(calls.last.payload, {'color': 19});
    // Everything in between is dropped, not sent late one by one.
    expect(calls.length, lessThanOrEqualTo(PresenceThrottle.budget + 1));
    expect(calls.last.at, lessThanOrEqualTo(_serverWindow));
  });

  test('a whole evening of lobby and rounds stays below the limit', () {
    final calls = _run((throttle, async) {
      // A presence change every three seconds for half an hour: team pick,
      // round start, death, back to the lobby, and so on.
      for (var i = 0; i < 600; i++) {
        if (i % 7 == 6) {
          throttle.untrack();
        } else {
          throttle.track({'step': i});
        }
        async.elapse(const Duration(seconds: 3));
      }
    });
    expect(_busiestWindow(calls), lessThan(_serverLimit));
    expect(calls.last.payload, {'step': 599});
  });

  test('taking a listing off and putting it back is merged into one call', () {
    final calls = _run((throttle, async) {
      for (var i = 0; i < PresenceThrottle.budget; i++) {
        throttle.track({'players': i + 1});
      }
      // The budget is spent: both of these wait, and only the last counts.
      throttle
        ..untrack()
        ..track({'players': 9});
    });
    expect(calls.map((c) => c.payload), [
      {'players': 1},
      {'players': 2},
      {'players': 3},
      {'players': 4},
      {'players': 9},
    ]);
    expect(calls.last.at, _serverWindow);
  });

  test('an untrack that comes last goes out as an untrack', () {
    final calls = _run((throttle, async) {
      for (var i = 0; i < PresenceThrottle.budget; i++) {
        throttle.track({'players': i + 1});
      }
      throttle.untrack();
    });
    expect(calls, hasLength(PresenceThrottle.budget + 1));
    expect(calls.last.payload, isNull);
  });

  test('a closed throttle sends nothing more', () {
    final calls = _run((throttle, async) {
      for (var i = 0; i < PresenceThrottle.budget + 3; i++) {
        throttle.track({'step': i});
      }
      throttle.close();
      throttle.track({'step': 99});
    });
    expect(calls, hasLength(PresenceThrottle.budget));
  });
}
