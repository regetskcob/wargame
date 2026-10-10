import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

/// Records what never changes once into a picture and replays it on every
/// frame. The ground and the defense field drew hundreds of shapes, and made
/// as many paints, each frame for a layer that stays the same all round.
///
/// With a [bakeArea] the recording is drawn once more into an image of that
/// stretch of the world, and the image is what each frame shows. A picture
/// still fills every shape anew on the graphics chip; large soft gradients
/// (the hills) cost several milliseconds a frame on an older iPad that way,
/// one image of them next to nothing.
mixin StaticPicture on Component {
  Picture? _picture;
  Image? _image;

  /// Paints the unchanging part. Called once, and again after
  /// [invalidateStatic].
  void paintStatic(Canvas canvas);

  /// The stretch of the world to bake into an image, or null to replay the
  /// recording.
  Rect? get bakeArea => null;

  /// The longest side of the baked image in pixels: enough for soft
  /// shapes, and a few megabytes at most.
  static const maxBakeSide = 1536.0;

  void renderStatic(Canvas canvas) {
    final area = bakeArea;
    if (area != null && !area.isEmpty) {
      final image = _image ??= _bake(area);
      if (image != null) {
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          area,
          Paint()..filterQuality = FilterQuality.low,
        );
        return;
      }
    }
    var picture = _picture;
    if (picture == null) {
      final recorder = PictureRecorder();
      paintStatic(Canvas(recorder));
      picture = _picture = recorder.endRecording();
    }
    canvas.drawPicture(picture);
  }

  Image? _bake(Rect area) {
    final scale = min(1.0, maxBakeSide / max(area.width, area.height));
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(scale)
      ..translate(-area.left, -area.top);
    paintStatic(canvas);
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(
        max(1, (area.width * scale).ceil()),
        max(1, (area.height * scale).ceil()),
      );
    } on Object {
      // Without a graphics backend (tests) the recording is replayed.
      return null;
    } finally {
      picture.dispose();
    }
  }

  /// Drops the recording, for when what it shows changed.
  void invalidateStatic() {
    _picture?.dispose();
    _picture = null;
    _image?.dispose();
    _image = null;
  }

  @override
  void onRemove() {
    invalidateStatic();
    super.onRemove();
  }
}
