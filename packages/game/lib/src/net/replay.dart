import 'net_events.dart';
import 'payloads/round_start_payload.dart';

/// One message of a round, [at] milliseconds after the round started.
class ReplayEvent {
  const ReplayEvent(this.at, this.event, this.payload);

  final int at;
  final NetEvent event;
  final Map<String, dynamic> payload;
}

/// Everything needed to watch a round again. The world follows from the
/// seed, so only the messages the tanks exchanged are kept: what this client
/// sent and what it received, in order.
class Replay {
  Replay({
    required this.round,
    required this.names,
    required this.styles,
    required this.events,
  });

  final RoundStartPayload round;

  /// Names and looks of the tanks, which may have left the room since.
  final Map<String, String> names;
  final Map<String, int> styles;
  final List<ReplayEvent> events;

  /// Milliseconds from the round start to the last message.
  int get length => events.isEmpty ? 0 : events.last.at;
}

/// Collects the messages of the current round.
class ReplayRecorder {
  /// Safety cap, roughly ten minutes of a full room.
  static const maxEvents = 120000;

  RoundStartPayload? _round;
  Map<String, String> _names = const {};
  Map<String, int> _styles = const {};
  final _events = <ReplayEvent>[];

  bool get recording => _round != null;

  void start(
    RoundStartPayload round, {
    required Map<String, String> names,
    required Map<String, int> styles,
  }) {
    _round = round;
    _names = names;
    _styles = styles;
    _events.clear();
  }

  void add(NetEvent event, Map<String, dynamic> payload) {
    final round = _round;
    if (round == null ||
        event == NetEvent.roundStart ||
        _events.length >= maxEvents) {
      return;
    }
    _events.add(
      ReplayEvent(
        DateTime.now().millisecondsSinceEpoch - round.startedAt,
        event,
        payload,
      ),
    );
  }

  /// Ends the recording and hands it over, null when nothing was recorded.
  Replay? finish() {
    final round = _round;
    _round = null;
    if (round == null || _events.isEmpty) {
      return null;
    }
    return Replay(
      round: round,
      names: _names,
      styles: _styles,
      events: List.of(_events),
    );
  }
}

/// Hands out the messages of a [Replay] as their time comes, with the round
/// moved to start at [startedAt].
class ReplayPlayer {
  ReplayPlayer(this.replay, {required this.startedAt});

  final Replay replay;
  final int startedAt;
  var _next = 0;

  /// How far the original round start moved, to shift absolute times in the
  /// messages, such as when a barrage lands.
  int get shift => startedAt - replay.round.startedAt;

  bool get done => _next >= replay.events.length;

  /// Messages due at [now], milliseconds since the epoch.
  Iterable<ReplayEvent> due(int now) sync* {
    final elapsed = now - startedAt;
    while (_next < replay.events.length && replay.events[_next].at <= elapsed) {
      yield replay.events[_next++];
    }
  }
}
