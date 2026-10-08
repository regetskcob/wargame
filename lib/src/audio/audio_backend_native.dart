import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'audio_backend.dart';

AudioBackend createAudioBackend() => _NativeAudioBackend();

/// A fixed set of players per sound, loaded once and restarted for every
/// shot. A fresh player per sound piles up native players in a heavy fight
/// and, on iOS, writes the file anew for each one. That kept the main thread
/// so busy that taps no longer came through.
class _NativeAudioBackend implements AudioBackend {
  /// Sounds that overlap in a fight get a few voices, the rest one.
  static const _voices = {
    'cannon': 3,
    'autocannon': 3,
    'hit': 3,
    'explosion': 3,
  };

  /// The same sound again within this time adds nothing but load.
  static const _minGap = Duration(milliseconds: 60);

  final _pools = <String, List<_Voice>>{};
  final _next = <String, int>{};
  final _lastPlayed = <String, DateTime>{};
  AudioPlayer? _loop;

  @override
  bool get hasLoop => _loop != null;

  static Source _source(String name) => AssetSource('audio/$name.wav');

  @override
  Future<void> load(Map<String, Uint8List> files) async {
    try {
      // The app has no mute button of its own: the sounds follow the silent
      // switch of the phone and play along with music from other apps.
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          // Ambient: silenced by the switch, mixes with other apps.
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {},
          ),
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
    } on Object catch (error) {
      debugPrint('Audio context failed: $error');
    }
    for (final name in files.keys) {
      if (name == 'engine') {
        continue;
      }
      final voices = <_Voice>[];
      for (var i = 0; i < (_voices[name] ?? 1); i++) {
        final player = AudioPlayer();
        try {
          await player.setReleaseMode(ReleaseMode.stop);
          await player.setSource(_source(name));
          voices.add(_Voice(player));
        } on Object catch (error) {
          debugPrint('Audio load failed for $name: $error');
          unawaited(player.dispose());
        }
      }
      _pools[name] = voices;
    }
  }

  @override
  void play(String name, double volume) {
    final voices = _pools[name];
    if (voices == null || voices.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final last = _lastPlayed[name];
    if (last != null && now.difference(last) < _minGap) {
      return;
    }
    _lastPlayed[name] = now;
    final index = (_next[name] ?? 0) % voices.length;
    _next[name] = index + 1;
    unawaited(voices[index].restart(volume));
  }

  @override
  Future<void> startLoop(String name, double volume) async {
    await stopLoop();
    final player = AudioPlayer();
    // Claimed before the first await, so a stop in the meantime finds it.
    _loop = player;
    try {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(volume);
      await player.play(_source(name));
    } on Object catch (error) {
      debugPrint('Engine sound failed: $error');
    }
    if (_loop != player) {
      await player.dispose();
    }
  }

  @override
  Future<void> adjustLoop({
    required double volume,
    required double rate,
  }) async {
    await _loop?.setVolume(volume);
    await _loop?.setPlaybackRate(rate);
  }

  @override
  Future<void> stopLoop() async {
    final player = _loop;
    _loop = null;
    await player?.stop();
    await player?.dispose();
  }
}

/// One loaded player, restarted from the top for each play.
class _Voice {
  _Voice(this.player);

  final AudioPlayer player;
  var _busy = false;

  Future<void> restart(double volume) async {
    // A restart still on its way to the platform: drop this one instead of
    // queueing more calls behind it.
    if (_busy) {
      return;
    }
    _busy = true;
    try {
      await player.stop();
      await player.setVolume(volume);
      await player.resume();
    } on Object catch (error) {
      debugPrint('Audio play failed: $error');
    } finally {
      _busy = false;
    }
  }
}
