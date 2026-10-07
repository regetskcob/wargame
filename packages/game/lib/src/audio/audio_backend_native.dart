import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'audio_backend.dart';

AudioBackend createAudioBackend() => _NativeAudioBackend();

class _NativeAudioBackend implements AudioBackend {
  final _sources = <String, BytesSource>{};
  AudioPlayer? _loop;

  @override
  bool get hasLoop => _loop != null;

  @override
  Future<void> load(Map<String, Uint8List> files) async {
    files.forEach((name, bytes) {
      _sources[name] = BytesSource(bytes, mimeType: 'audio/wav');
    });
  }

  @override
  void play(String name, double volume) {
    final source = _sources[name];
    if (source != null) {
      _playOnce(source, volume);
    }
  }

  Future<void> _playOnce(BytesSource source, double volume) async {
    final player = AudioPlayer();
    try {
      await player.setReleaseMode(ReleaseMode.release);
      await player.setVolume(volume);
      await player.play(source);
      // The stream is a mapped one whose futures are typed by the platform
      // event, so drop the value before giving it a void timeout handler.
      await player.onPlayerComplete.first
          .then<void>((_) {})
          .timeout(const Duration(seconds: 5), onTimeout: () {});
    } on Object catch (error) {
      debugPrint('Audio play failed: $error');
    } finally {
      await player.dispose();
    }
  }

  @override
  Future<void> startLoop(String name, double volume) async {
    final source = _sources[name];
    if (source == null) {
      return;
    }
    await stopLoop();
    final player = AudioPlayer();
    await player.setReleaseMode(ReleaseMode.loop);
    await player.setVolume(volume);
    await player.play(source);
    _loop = player;
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
