import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shown from the first frame until the game has loaded: the tank of the
/// launch screen on its ground, with a spinner below. Without it the screen
/// stayed dark while the app reached the server, between the launch screen
/// and the start page. The images come from `store/tool/launch_screen.py`.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  /// Decoded before the first frame so they are there at once and the
  /// change from the native launch screen is not seen.
  static ui.Image? ground;
  static ui.Image? tank;

  /// Width of the tank in points, as on the launch screen
  /// (`TANK_WIDTH` in `launch_screen.py`).
  static const tankWidth = 160.0;

  /// The middle colour of the ground, behind it while it loads.
  static const groundColor = Color(0xFF68733F);

  static const _spinnerColor = Color(0xFFE8DCB4);

  static Future<void> loadImages() async {
    ground = await _decode('assets/images/launch_ground.jpg');
    tank = await _decode('assets/images/launch_tank.png');
  }

  static Future<ui.Image?> _decode(String asset) async {
    try {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    } on Object {
      // Without the image the spinner alone still says the app is busy.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // The watch is narrower than the tank is meant for.
    final width = min(tankWidth, MediaQuery.sizeOf(context).shortestSide * 0.6);
    final image = tank;
    final height = image == null
        ? width * 0.63
        : width * image.height / image.width;
    return ColoredBox(
      color: groundColor,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          RawImage(image: ground, fit: BoxFit.cover),
          Center(
            child: RawImage(
              image: image,
              width: width,
              height: height,
              filterQuality: FilterQuality.medium,
            ),
          ),
          Center(
            child: Transform.translate(
              offset: Offset(0, height * 0.5 + 40),
              child: const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _spinnerColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The loading view on its own, while `main` still sets up the store,
/// the language and the server session.
class LoadingApp extends StatelessWidget {
  const LoadingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: LoadingView(),
    );
  }
}
