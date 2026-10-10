import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/audio/audio_backend_native.dart';
import 'package:wargame/src/audio/sound_mixer.dart';

class _Voice implements SoundVoice {
  _Voice(this.volume, {this.playing = true});

  @override
  final double volume;
  final bool playing;

  @override
  bool get busy => false;

  @override
  bool playingAt(DateTime now) => playing;
}

void main() {
  var now = DateTime(2026);
  SoundMixer mixer() => SoundMixer(now: () => now);

  test('own sounds always pass, at their own level', () {
    final m = mixer();
    for (var i = 0; i < 50; i++) {
      expect(m.admit('cannon', 0.8, null), 0.8);
    }
  });

  test('sounds on the field fall off with distance and vanish far away', () {
    final m = mixer();
    final near = m.admit('cannon', 1, 100)!;
    now = now.add(const Duration(seconds: 1));
    final mid = m.admit('cannon', 1, 450)!;
    expect(near, greaterThan(mid));
    now = now.add(const Duration(seconds: 1));
    expect(m.admit('cannon', 1, 800), isNull);
  });

  test('a busy field lets only the loudest sounds through', () {
    final m = mixer();
    final names = ['cannon', 'hit', 'explosion', 'autocannon', 'squish'];
    for (final name in names) {
      expect(m.admit(name, 1, 400), isNotNull);
    }
    // The budget is full: a quieter one waits, a closer one gets in.
    expect(m.admit('tick', 1, 500), isNull);
    expect(m.admit('tick', 1, 50), isNotNull);
    // Once the moment has passed there is room again.
    now = now.add(SoundMixer.window);
    expect(m.admit('go', 1, 500), isNotNull);
  });

  test('a far gun repeating itself is left out', () {
    final m = mixer();
    expect(m.admit('cannon', 1, 300), isNotNull);
    now = now.add(const Duration(milliseconds: 30));
    expect(m.admit('cannon', 1, 300), isNull);
  });

  test('a new sound takes a free voice, else only a quieter one', () {
    final at = DateTime(2026);
    final free = _Voice(1, playing: false);
    final quiet = _Voice(0.2);
    final loud = _Voice(0.9);
    expect(pickVoice([loud, quiet, free], 0.1, at), same(free));
    expect(pickVoice([loud, quiet], 0.5, at), same(quiet));
    expect(pickVoice([loud, quiet], 0.1, at), isNull);
  });

  test('the length of every sound is read from its file', () {
    for (final file in Directory('assets/audio').listSync()) {
      final length = wavLength(File(file.path).readAsBytesSync());
      expect(length, greaterThan(const Duration(milliseconds: 50)));
      expect(length, lessThan(const Duration(seconds: 3)));
    }
    final cannon = wavLength(File('assets/audio/cannon.wav').readAsBytesSync());
    expect(cannon.inMilliseconds, closeTo(550, 20));
  });
}
