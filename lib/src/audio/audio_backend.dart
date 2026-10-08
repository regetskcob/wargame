import 'dart:typed_data';

/// Plays the game's sounds. The web build talks to the Web Audio API
/// directly, everything else goes through audioplayers.
abstract class AudioBackend {
  /// Hands over the encoded sound files by name.
  Future<void> load(Map<String, Uint8List> files);

  /// Plays [name] once at [volume] (0 to 1).
  void play(String name, double volume);

  /// Starts [name] as a loop, replacing a running one.
  Future<void> startLoop(String name, double volume);

  /// Changes the running loop's volume and pitch (1 is normal).
  Future<void> adjustLoop({required double volume, required double rate});

  Future<void> stopLoop();

  bool get hasLoop;
}
