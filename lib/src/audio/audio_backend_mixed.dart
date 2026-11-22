import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'audio_backend.dart';

/// Plays every sound through one native mixer (SoLoud): a single output
/// stream, every shot a voice inside it. The players of audioplayers were
/// one AVPlayer each on iOS, and winding them back cost the BoPad about
/// ten frames a second at defense wave 30, see `audio_backend_native.dart`.
///
/// It leaves the audio session to the app, so the ambient category the
/// native backend sets still decides: silent switch, music of other apps.
class MixedAudioBackend implements AudioBackend {
  MixedAudioBackend(this._soloud);

  final SoLoud _soloud;

  /// Voices one sound of the field may hold at once; a new one past that
  /// takes the place of the oldest. The player's own never count.
  static const fieldVoices = 4;

  final _sources = <String, AudioSource>{};
  final _field = <String, List<SoundHandle>>{};
  final _own = <String, List<SoundHandle>>{};
  SoundHandle? _loop;

  @override
  bool get hasLoop => _loop != null;

  @override
  Future<void> load(Map<String, Uint8List> files) async {
    // Loaded again: the old sources and the loop stay with this mixer.
    await stopLoop();
    if (!_soloud.isInitialized) {
      // A small buffer: a shot should be heard in the frame it is fired.
      await _soloud.init(bufferSize: 1024);
    }
    for (final MapEntry(key: name, value: bytes) in files.entries) {
      _sources[name] = await _soloud.loadMem('$name.wav', bytes);
    }
  }

  @override
  void play(String name, double volume, {bool own = false}) {
    final source = _sources[name];
    if (source == null) {
      return;
    }
    try {
      final handle = _soloud.play(source, volume: volume);
      if (own) {
        // The mixer drops the quietest voices first when it runs out; the
        // own shot must never be among them. Capped like the field's, or
        // a fast gun would fill the mixer with voices nobody may drop.
        _soloud.setProtectVoice(handle, true);
      }
      final voices = ((own ? _own : _field)[name] ??= [])
        ..removeWhere((h) => !_soloud.getIsValidVoiceHandle(h))
        ..add(handle);
      if (voices.length > fieldVoices) {
        unawaited(_soloud.stop(voices.removeAt(0)));
      }
    } on Object catch (error) {
      debugPrint('Sound $name failed: $error');
    }
  }

  @override
  Future<void> startLoop(String name, double volume) async {
    await stopLoop();
    final source = _sources[name];
    if (source == null) {
      return;
    }
    try {
      _loop = _soloud.play(source, volume: volume, looping: true);
    } on Object catch (error) {
      debugPrint('Loop $name failed: $error');
    }
  }

  @override
  Future<void> adjustLoop({
    required double volume,
    required double rate,
  }) async {
    final loop = _loop;
    if (loop == null) {
      return;
    }
    // Called every frame: a loop the mixer lost (an interruption, a
    // restart of the engine) is let go instead of throwing each time.
    try {
      if (!_soloud.getIsValidVoiceHandle(loop)) {
        _loop = null;
        return;
      }
      _soloud
        ..setVolume(loop, volume)
        ..setRelativePlaySpeed(loop, rate);
    } on Object catch (error) {
      _loop = null;
      debugPrint('Loop adjustment failed: $error');
    }
  }

  @override
  Future<void> stopLoop() async {
    final loop = _loop;
    _loop = null;
    if (loop != null) {
      try {
        await _soloud.stop(loop);
      } on Object catch (error) {
        debugPrint('Stopping the loop failed: $error');
      }
    }
  }
}
