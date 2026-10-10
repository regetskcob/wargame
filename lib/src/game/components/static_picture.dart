import 'dart:ui';

import 'package:flame/components.dart';

/// Records what never changes once into a picture and replays it on every
/// frame. The ground and the defense field drew hundreds of shapes, and made
/// as many paints, each frame for a layer that stays the same all round.
mixin StaticPicture on Component {
  Picture? _picture;

  /// Paints the unchanging part. Called once, and again after
  /// [invalidateStatic].
  void paintStatic(Canvas canvas);

  void renderStatic(Canvas canvas) {
    var picture = _picture;
    if (picture == null) {
      final recorder = PictureRecorder();
      paintStatic(Canvas(recorder));
      picture = _picture = recorder.endRecording();
    }
    canvas.drawPicture(picture);
  }

  /// Drops the recording, for when what it shows changed.
  void invalidateStatic() {
    _picture?.dispose();
    _picture = null;
  }

  @override
  void onRemove() {
    invalidateStatic();
    super.onRemove();
  }
}
