import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/audio/audio_backend_native.dart';

/// A player whose calls are answered when the test says so, like the
/// phone's main thread under load.
class _SlowPlayer implements VoicePlayer {
  final calls = <String>[];
  final _waiting = <Completer<void>>[];
  bool answerAtOnce = true;

  Future<void> _call(String name) {
    calls.add(name);
    if (answerAtOnce) {
      return Future.value();
    }
    final done = Completer<void>();
    _waiting.add(done);
    return done.future;
  }

  void answer() => _waiting.removeAt(0).complete();

  /// Answers every call, including the ones the answers lead to.
  Future<void> answerAll() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
      while (_waiting.isNotEmpty) {
        answer();
      }
    }
  }

  @override
  Future<void> stop() => _call('stop');

  @override
  Future<void> setVolume(double volume) => _call('volume');

  @override
  Future<void> resume() => _call('resume');
}

void main() {
  var now = DateTime(2026, 10, 11, 12);
  late VoiceTraffic traffic;
  setUp(() {
    now = DateTime(2026, 10, 11, 12);
    traffic = VoiceTraffic(now: () => now);
  });
  const length = Duration(milliseconds: 500);

  test('a voice counts as taken until its sound is through and wound '
      'back', () async {
    final player = _SlowPlayer();
    final voice = Voice(player, traffic);
    expect(voice.playingAt(now), isFalse);
    expect(await voice.restart(0.5, length), isTrue);
    // Always from the top: a stop, which costs nothing once wound back.
    expect(player.calls, ['stop', 'volume', 'resume']);
    expect(voice.playingAt(now.add(length)), isTrue);
    expect(voice.playingAt(now.add(length + Voice.settle)), isFalse);
  });

  test('sounds of the field queue for nothing', () async {
    final players = [for (var i = 0; i < 5; i++) _SlowPlayer()];
    for (final player in players) {
      player.answerAtOnce = false;
    }
    final voices = [for (final p in players) Voice(p, traffic)];
    final started = [
      for (final voice in voices.take(3)) voice.restart(0.5, length),
    ];
    expect(traffic.pending, 3);
    // The queue is full: the fourth is left out at once, and so is a
    // second sound for a voice still busy.
    expect(await voices[3].restart(0.5, length), isFalse);
    expect(players[3].calls, isEmpty);
    expect(await voices[0].restart(0.9, length), isFalse);

    // The player's own sound still goes.
    final own = voices[4].restart(1, length, own: true);
    expect(players[4].calls, ['stop']);

    // The platform answers within the limit: they play.
    for (final player in [...players.take(3), players[4]]) {
      await player.answerAll();
    }
    expect(await Future.wait([...started, own]), everyElement(isTrue));
    expect(traffic.pending, 0);
  });

  test('a sound that would start late is left out', () async {
    final player = _SlowPlayer();
    final voice = Voice(player, traffic);
    expect(await voice.restart(0.5, length), isTrue);
    now = now.add(const Duration(milliseconds: 100));
    player
      ..calls.clear()
      ..answerAtOnce = false;
    final late = voice.restart(0.5, length);
    expect(player.calls, ['stop']);
    // The stop takes longer than the limit.
    now = now.add(traffic.late + const Duration(milliseconds: 1));
    player.answer();
    expect(await late, isFalse);
    expect(player.calls, ['stop']);
    expect(voice.playingAt(now), isFalse);
    expect(voice.busy, isFalse);

    // The player's own sound neither: silence is better than a shot heard
    // seconds after it was fired.
    player.calls.clear();
    final own = voice.restart(1, length, own: true);
    now = now.add(const Duration(seconds: 1));
    await player.answerAll();
    expect(await own, isFalse);
    expect(player.calls, ['stop']);
  });

  test('a stop stuck on the platform shuts nobody out', () async {
    final stuck = _SlowPlayer();
    final voices = [
      for (var i = 0; i < 3; i++) Voice(stuck..answerAtOnce = false, traffic),
    ];
    for (final voice in voices) {
      unawaited(voice.restart(0.5, length));
    }
    expect(traffic.full, isTrue);
    // Winding back took seconds on the BoPad, while other voices' calls
    // passed it: once late, those restarts no longer count.
    now = now.add(traffic.late + const Duration(milliseconds: 1));
    expect(traffic.pending, 3);
    expect(traffic.full, isFalse);
    expect(await Voice(_SlowPlayer(), traffic).restart(0.5, length), isTrue);
  });

  test('the own sound only takes a voice that played through', () async {
    final a = Voice(_SlowPlayer(), traffic);
    final b = Voice(_SlowPlayer(), traffic);
    expect(pickFree([a, b], now), same(a));
    await a.restart(1, length, own: true);
    expect(pickFree([a, b], now), same(b));
    await b.restart(1, length, own: true);
    // Both still sounding: none is stopped halfway for it.
    expect(pickFree([a, b], now), isNull);
    // Played through but not yet wound back: still not free.
    now = now.add(length);
    expect(pickFree([a, b], now), isNull);
    now = now.add(Voice.settle);
    expect(pickFree([a, b], now), same(a));
  });

  test('a player that fails leaves the voice free', () async {
    final voice = Voice(_FailingPlayer(), traffic);
    expect(await voice.restart(0.5, length), isFalse);
    expect(voice.busy, isFalse);
    expect(traffic.pending, 0);
  });
}

class _FailingPlayer implements VoicePlayer {
  @override
  Future<void> stop() async {}

  @override
  Future<void> setVolume(double volume) async =>
      throw StateError('player disposed');

  @override
  Future<void> resume() async {}
}
