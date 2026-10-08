import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../net/room_code.dart';
import '../theme.dart';
import '../../l10n/l10n.dart';

/// Full screen camera that reads the QR code of a waiting room and returns
/// its code. Only in the apps: in the browser the phone camera opens the
/// room link by itself.
class RoomScanner extends StatefulWidget {
  const RoomScanner({super.key});

  /// Opens the camera, resolves to the scanned room code or null.
  static Future<String?> scan(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const RoomScanner(),
      ),
    );
  }

  @override
  State<RoomScanner> createState() => _RoomScannerState();
}

class _RoomScannerState extends State<RoomScanner> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  var _done = false;
  String? _rejected;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _detect(BarcodeCapture capture) {
    if (_done) {
      return;
    }
    for (final barcode in capture.barcodes) {
      final text = barcode.rawValue;
      if (text == null) {
        continue;
      }
      final code = roomCodeFrom(text);
      if (code != null) {
        _done = true;
        Navigator.of(context).pop(code);
        return;
      }
      if (_rejected != text) {
        setState(() => _rejected = text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: BwColors.background,
        title: Text(tr('RAUM SCANNEN', 'SCAN ROOM')),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _detect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? tr(
                          'Kein Zugriff auf die Kamera. Erlaube ihn in den '
                              'Einstellungen oder gib den Raumcode von Hand ein.',
                          'No access to the camera. Allow it in the settings '
                              'or enter the room code by hand.',
                        )
                      : tr(
                          'Die Kamera lässt sich nicht starten. Gib den '
                              'Raumcode von Hand ein.',
                          'The camera cannot be started. Enter the room '
                              'code by hand.',
                        ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: BwColors.amber, width: 3),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.all(24),
              child: Text(
                _rejected == null
                    ? tr(
                        'Halte die Kamera auf den QR-Code im Warteraum.',
                        'Point the camera at the QR code in the waiting room.',
                      )
                    : tr(
                        'Das ist kein Raum-Code von Panzergefecht.',
                        'This is not a Panzergefecht room code.',
                      ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
