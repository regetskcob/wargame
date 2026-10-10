import 'dart:math';

/// Decides which sounds of a busy battlefield are worth playing. Late in a
/// defense round dozens of guns, aircraft and blasts go off each second:
/// played all at once they cut each other off and stuttered on a phone
/// ("Ton hakt sehr rum"), and the player's own shots were lost among them.
///
/// The own sounds (no distance) always pass. Sounds out on the field get
/// quieter with distance and share a small budget per moment: a quiet one
/// waits its turn behind a louder one, a far gun repeating itself is left
/// out.
class SoundMixer {
  SoundMixer({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// Distance in world units beyond which a sound is not heard at all.
  static const hearing = 900.0;

  /// Sounds on the field quieter than this are not worth a voice.
  static const floor = 0.08;

  /// How many sounds on the field may start within [window].
  static const budget = 5;
  static const window = Duration(milliseconds: 250);

  /// The same sound on the field again within this time adds nothing.
  static const repeatGap = Duration(milliseconds: 90);

  final _recent = <(DateTime, double)>[];
  final _lastOf = <String, DateTime>{};

  /// The volume to play [name] at, or null to leave it out. [volume] is the
  /// sound's own level, [distance] how far from the camera it happens,
  /// null for the player's own sounds.
  double? admit(String name, double volume, double? distance) {
    if (distance == null) {
      return volume.clamp(0.0, 1.0);
    }
    // Squared, so the near field stays loud and the far one falls off fast.
    final fall = max(0.0, 1 - distance / hearing);
    final level = (volume * fall * fall).clamp(0.0, 1.0);
    if (level < floor) {
      return null;
    }
    final now = _now();
    final last = _lastOf[name];
    if (last != null && now.difference(last) < repeatGap) {
      return null;
    }
    _recent.removeWhere((entry) => now.difference(entry.$1) >= window);
    if (_recent.length >= budget) {
      // Full: only a sound louder than the quietest one let in may pass,
      // so what happens close by is not drowned by the far side.
      final quietest = _recent.map((entry) => entry.$2).reduce(min);
      if (level <= quietest) {
        return null;
      }
      _recent.remove(_recent.firstWhere((entry) => entry.$2 == quietest));
    }
    _recent.add((now, level));
    _lastOf[name] = now;
    return level;
  }
}
