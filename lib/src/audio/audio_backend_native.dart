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
  /// Voices per sound for what happens on the field. Late in a defense round
  /// three voices, restarted in turn, cut each sound off half way and it
  /// stuttered; now a new sound takes a free voice, or the quietest one if it
  /// is louder than that.
  static const _voices = {
    'cannon': 3,
    'autocannon': 3,
    'hit': 3,
    'explosion': 3,
  };

  /// Sounds the player makes get a voice of their own that nothing from the
  /// field can take: the own shot was lost among the guns before.
  static const _ownVoices = {'cannon', 'autocannon', 'hit', 'explosion'};

  /// Length of each sound, read from its file, to know when a voice is free.
  final _lengths = <String, Duration>{};

  final _pools = <String, List<_Voice>>{};
  final _own = <String, _Voice>{};
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
    for (final MapEntry(key: name, value: bytes) in files.entries) {
      if (name == 'engine') {
        continue;
      }
      _lengths[name] = wavLength(bytes);
      final voices = <_Voice>[];
      for (var i = 0; i < (_voices[name] ?? 1); i++) {
        final voice = await _voice(name);
        if (voice != null) {
          voices.add(voice);
        }
      }
      _pools[name] = voices;
      if (_ownVoices.contains(name)) {
        final voice = await _voice(name);
        if (voice != null) {
          _own[name] = voice;
        }
      }
    }
  }

  Future<_Voice?> _voice(String name) async {
    final player = AudioPlayer();
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setSource(_source(name));
      return _Voice(player);
    } on Object catch (error) {
      debugPrint('Audio load failed for $name: $error');
      unawaited(player.dispose());
      return null;
    }
  }

  @override
  void play(String name, double volume, {bool own = false}) {
    final now = DateTime.now();
    final length = _lengths[name] ?? Duration.zero;
    final voice = own && _own.containsKey(name)
        ? _own[name]
        : pickVoice(_pools[name] ?? const <_Voice>[], volume, now);
    if (voice == null) {
      return;
    }
    unawaited(voice.restart(volume, now.add(length)));
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

/// The voice for a new sound at [volume]: a free one, else the quietest
/// one still playing if the new sound is louder, else none.
@visibleForTesting
T? pickVoice<T extends SoundVoice>(
  List<T> voices,
  double volume,
  DateTime now,
) {
  T? quietest;
  for (final voice in voices) {
    if (voice.busy) {
      continue;
    }
    if (!voice.playingAt(now)) {
      return voice;
    }
    if (quietest == null || voice.volume < quietest.volume) {
      quietest = voice;
    }
  }
  return quietest != null && volume > quietest.volume ? quietest : null;
}

/// What [pickVoice] needs to know of a voice.
abstract class SoundVoice {
  /// Still handing a restart to the platform.
  bool get busy;

  /// Level of the sound it plays or played last.
  double get volume;

  bool playingAt(DateTime now);
}

/// One loaded player, restarted from the top for each play.
class _Voice implements SoundVoice {
  _Voice(this.player);

  final AudioPlayer player;

  @override
  var busy = false;

  @override
  var volume = 0.0;

  DateTime _endsAt = DateTime(0);

  @override
  bool playingAt(DateTime now) => now.isBefore(_endsAt);

  Future<void> restart(double volume, DateTime endsAt) async {
    // A restart still on its way to the platform: drop this one instead of
    // queueing more calls behind it.
    if (busy) {
      return;
    }
    busy = true;
    this.volume = volume;
    _endsAt = endsAt;
    try {
      await player.stop();
      await player.setVolume(volume);
      await player.resume();
    } on Object catch (error) {
      debugPrint('Audio play failed: $error');
    } finally {
      busy = false;
    }
  }
}

/// Length of a PCM WAV file from its header, zero when it cannot be read.
@visibleForTesting
Duration wavLength(Uint8List bytes) {
  if (bytes.length < 44) {
    return Duration.zero;
  }
  final data = ByteData.sublistView(bytes);
  var byteRate = 0;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = data.getUint32(offset + 4, Endian.little);
    if (id == 'fmt ') {
      byteRate = data.getUint32(offset + 16, Endian.little);
    } else if (id == 'data' && byteRate > 0) {
      return Duration(microseconds: size * 1000000 ~/ byteRate);
    }
    offset += 8 + size + size % 2;
  }
  return Duration.zero;
}
