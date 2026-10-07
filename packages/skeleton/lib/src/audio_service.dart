import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio/audio_backend.dart';
import 'audio/audio_backend_native.dart'
    if (dart.library.js_interop) 'audio/audio_backend_web.dart';

/// Sound effects. All files are synthesised by `tool/gen_sounds.py`.
class AudioService {
  static const _files = [
    'cannon',
    'autocannon',
    'hit',
    'explosion',
    'tick',
    'go',
    'win',
    'lose',
    'engine',
    'squish',
  ];

  static final muted = ValueNotifier<bool>(false);
  static final AudioBackend _backend = createAudioBackend();
  static bool _ready = false;
  static bool _engineStarting = false;

  static Future<void> init() async {
    try {
      final files = <String, Uint8List>{};
      for (final name in _files) {
        final data = await rootBundle.load('assets/audio/$name.wav');
        files[name] = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
      }
      await _backend.load(files);
      _ready = true;
    } on Object catch (error) {
      debugPrint('Audio disabled: $error');
    }
  }

  /// Plays [name] at [volume], which is lowered the further the sound is from
  /// the camera when [distance] is given.
  static void play(String name, {double volume = 1, double? distance}) {
    if (!_ready || muted.value) {
      return;
    }
    var v = volume;
    if (distance != null) {
      v *= max(0.0, 1 - distance / 900);
    }
    if (v <= 0.02) {
      return;
    }
    try {
      _backend.play(name, v.clamp(0.0, 1.0));
    } on Object catch (error) {
      debugPrint('Audio play failed: $error');
    }
  }

  /// Keeps the engine loop running and matches pitch and volume to [load],
  /// the speed as a share of the top speed.
  static Future<void> engine(double load) async {
    if (!_ready || muted.value) {
      await stopEngine();
      return;
    }
    final level = load.clamp(0.0, 1.0);
    if (!_backend.hasLoop) {
      if (!_engineStarting) {
        _engineStarting = true;
        try {
          await _backend.startLoop('engine', 0.12);
        } on Object catch (error) {
          debugPrint('Engine sound failed: $error');
        } finally {
          _engineStarting = false;
        }
      }
      return;
    }
    await _backend.adjustLoop(
      volume: 0.1 + 0.25 * level,
      rate: 0.8 + 0.7 * level,
    );
  }

  static Future<void> stopEngine() async {
    if (_backend.hasLoop) {
      await _backend.stopLoop();
    }
  }
}
