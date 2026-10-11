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

  /// Sounds the player makes get voices of their own that nothing from the
  /// field can take: the own shot was lost among the guns before. Three, so
  /// the next shot finds one that played through: taken in the middle of
  /// its sound a voice has to be stopped and wound back first, and on the
  /// BoPad in defense wave 30 that took seconds, in which the own gun
  /// stayed silent or was heard late.
  static const _ownVoices = {'cannon', 'autocannon', 'hit', 'explosion'};
  static const _ownCount = 3;

  /// Length of each sound, read from its file, to know when a voice is free.
  final _lengths = <String, Duration>{};

  final _traffic = VoiceTraffic();
  final _pools = <String, List<Voice>>{};
  final _own = <String, List<Voice>>{};
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
      final voices = <Voice>[];
      for (var i = 0; i < (_voices[name] ?? 1); i++) {
        final voice = await _voice(name);
        if (voice != null) {
          voices.add(voice);
        }
      }
      _pools[name] = voices;
      if (_ownVoices.contains(name)) {
        final own = <Voice>[];
        for (var i = 0; i < _ownCount; i++) {
          final voice = await _voice(name);
          if (voice != null) {
            own.add(voice);
          }
        }
        _own[name] = own;
      }
    }
  }

  /// A player that does not ask the platform where it is: audioplayers
  /// does that once a frame for every player that plays, a call each to
  /// the main thread. With the engine and a dozen voices on the field that
  /// was well over a thousand calls a second at 120 Hz, and nothing here
  /// reads the position.
  static AudioPlayer _player() => AudioPlayer()..positionUpdater = null;

  Future<Voice?> _voice(String name) async {
    final player = _player();
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setSource(_source(name));
      return Voice(_Player(player), _traffic);
    } on Object catch (error) {
      debugPrint('Audio load failed for $name: $error');
      unawaited(player.dispose());
      return null;
    }
  }

  @override
  void play(String name, double volume, {bool own = false}) {
    final length = _lengths[name] ?? Duration.zero;
    final now = _traffic.now();
    // The own sounds only take a voice that played through: one stopped
    // halfway could hold the next shots up for seconds, see [_ownVoices].
    final voice = own
        ? pickFree(_own[name] ?? _pools[name] ?? const <Voice>[], now)
        : pickVoice(_pools[name] ?? const <Voice>[], volume, now);
    if (voice == null) {
      return;
    }
    unawaited(voice.restart(volume, length, own: own));
  }

  @override
  Future<void> startLoop(String name, double volume) async {
    await stopLoop();
    final player = _player();
    // Claimed before the first await, so a stop in the meantime finds it.
    _loop = player;
    try {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(volume);
      await player.play(_source(name));
    } on Object catch (error) {
      // Also when a stop took the player while it was starting: that stop
      // disposed it, and disposing it a second time threw unhandled.
      debugPrint('Engine sound failed: $error');
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
    try {
      await player?.stop();
      await player?.dispose();
    } on Object catch (error) {
      // A player that never got going cannot be stopped; it is gone anyway.
      debugPrint('Engine sound failed: $error');
    }
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

/// A voice that is neither busy nor playing, or none.
@visibleForTesting
T? pickFree<T extends SoundVoice>(List<T> voices, DateTime now) {
  for (final voice in voices) {
    if (!voice.busy && !voice.playingAt(now)) {
      return voice;
    }
  }
  return null;
}

/// What [pickVoice] needs to know of a voice.
abstract class SoundVoice {
  /// Still handing a restart to the platform.
  bool get busy;

  /// Level of the sound it plays or played last.
  double get volume;

  bool playingAt(DateTime now);
}

/// What a voice needs of its player: an [AudioPlayer] in the app, a fake
/// in the tests.
@visibleForTesting
abstract class VoicePlayer {
  Future<void> stop();
  Future<void> setVolume(double volume);
  Future<void> resume();
}

class _Player implements VoicePlayer {
  _Player(this.player);

  final AudioPlayer player;

  @override
  Future<void> stop() => player.stop();

  @override
  Future<void> setVolume(double volume) => player.setVolume(volume);

  @override
  Future<void> resume() => player.resume();
}

/// What all voices share: how many restarts are on their way to the
/// platform right now.
///
/// Every call to a player crosses to the phone's main thread and, on iOS,
/// on to the media daemon that runs the players. On the BoPad in defense
/// wave 30 the field asked for about 15 sounds a second, and winding a
/// voice back to its start took that daemon up to 19 seconds: half the
/// sounds were heard seconds after what made them. Now a sound of the
/// field waits in no queue: with [limit] restarts under way it is left
/// out, and no sound, the player's own neither, starts once it is [late]:
/// silence is better than a shot heard seconds after it was fired.
@visibleForTesting
class VoiceTraffic {
  VoiceTraffic({
    this.limit = 3,
    this.late = const Duration(milliseconds: 120),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final int limit;
  final Duration late;
  final DateTime Function() now;

  /// When each restart now on its way to the platform was asked for.
  final _pending = <DateTime>[];

  /// Restarts handed to the platform and not answered yet.
  int get pending => _pending.length;

  /// Whether [limit] restarts are under way that are not late yet. A late
  /// one no longer counts: winding a voice back can take the platform
  /// seconds, while the calls of other voices pass it, so it holds nobody
  /// up but would have shut out the whole field.
  bool get full {
    final since = now().subtract(late);
    return _pending.where((at) => at.isAfter(since)).length >= limit;
  }

  void _start(DateTime at) => _pending.add(at);

  void _end(DateTime at) => _pending.remove(at);
}

/// One loaded player, restarted from the top for each play.
@visibleForTesting
class Voice implements SoundVoice {
  Voice(this.player, this.traffic);

  final VoicePlayer player;
  final VoiceTraffic traffic;

  /// Time the platform takes to wind a finished sound back to its start.
  /// Until then a stop has to wind it back itself, which took the BoPad
  /// seconds in a late wave; after it a stop costs next to nothing.
  static const settle = Duration(milliseconds: 100);

  @override
  var busy = false;

  @override
  var volume = 0.0;

  DateTime _endsAt = DateTime(0);

  /// Until its sound is through and wound back.
  @override
  bool playingAt(DateTime now) => now.isBefore(_endsAt);

  /// Plays the sound of [length] from the top at [volume] and says whether
  /// it started. A busy voice or a late answer drop it, for a sound of the
  /// field also a full queue, see [VoiceTraffic].
  Future<bool> restart(
    double volume,
    Duration length, {
    bool own = false,
  }) async {
    // A restart still on its way to the platform: drop this one instead of
    // queueing more calls behind it.
    if (busy || (!own && traffic.full)) {
      return false;
    }
    final asked = traffic.now();
    busy = true;
    traffic._start(asked);
    this.volume = volume;
    // Taken from now on, so the next sound picks another voice.
    _endsAt = asked.add(length + settle);
    try {
      await player.stop();
      if (traffic.now().difference(asked) > traffic.late) {
        // Too late to belong to what the player sees.
        _endsAt = DateTime(0);
        return false;
      }
      await player.setVolume(volume);
      await player.resume();
      _endsAt = traffic.now().add(length + settle);
      return true;
    } on Object catch (error) {
      debugPrint('Audio play failed: $error');
      _endsAt = DateTime(0);
      return false;
    } finally {
      busy = false;
      traffic._end(asked);
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
