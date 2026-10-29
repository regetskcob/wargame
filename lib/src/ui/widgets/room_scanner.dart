import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:horizont/horizont.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/routes.dart';
import '../../net/pad_link.dart';
import '../../net/room_code.dart';
import '../theme.dart';
import 'panel.dart';
import '../../l10n/l10n.dart';

/// Full screen camera that reads the QR code of a waiting room and returns
/// its code. Only in the apps: in the browser the phone camera opens the
/// room link by itself. It reads the pairing code of a screen the same way.
class RoomScanner extends StatefulWidget {
  const RoomScanner({this.pad = false, super.key});

  /// Reads the pairing code of a screen instead of a room.
  final bool pad;

  /// Opens the camera, resolves to the scanned room code or null.
  static Future<String?> scan(BuildContext context) =>
      context.push<String>(Routes.scanRoom);

  /// Opens the camera, resolves to the scanned pairing code or null.
  static Future<String?> scanPad(BuildContext context) =>
      context.push<String>(Routes.scanPad);

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
      final code = widget.pad ? padCodeFrom(text) : roomCodeFrom(text);
      if (code != null) {
        _done = true;
        context.pop(code);
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
      backgroundColor: GameColors.sunken,
      appBar: AppBar(
        backgroundColor: GameColors.bg,
        title: Text(
          widget.pad
              ? tr('BILDSCHIRM KOPPELN', 'PAIR SCREEN')
              : tr('RAUM SCANNEN', 'SCAN ROOM'),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _detect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(HzSpace.s24),
                child: Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? tr(
                          'Kein Zugriff auf die Kamera. Erlaube ihn in den '
                              'Einstellungen oder gib den Code von Hand ein.',
                          'No access to the camera. Allow it in the settings '
                              'or enter the code by hand.',
                        )
                      : tr(
                          'Die Kamera lässt sich nicht starten. Gib den '
                              'Code von Hand ein.',
                          'The camera cannot be started. Enter the code '
                              'by hand.',
                        ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          // Where the code goes: the selection line in the accent.
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(
                  color: GameColors.accentText,
                  width: HzLine.selection,
                ),
                borderRadius: BorderRadius.circular(HzRadius.r10),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.all(HzSpace.s24),
              child: _hint(switch ((widget.pad, _rejected == null)) {
                (false, true) => tr(
                  'Halte die Kamera auf den QR-Code im Warteraum.',
                  'Point the camera at the QR code in the waiting room.',
                ),
                (false, false) => tr(
                  'Das ist kein Raumcode von Panzergefecht.',
                  'This is not a Panzergefecht room code.',
                ),
                (true, true) => tr(
                  'Halte die Kamera auf den Kopplungscode am Bildschirm.',
                  'Point the camera at the pairing code on the screen.',
                ),
                (true, false) => tr(
                  'Das ist kein Kopplungscode von Panzergefecht.',
                  'This is not a Panzergefecht pairing code.',
                ),
              }),
            ),
          ),
        ],
      ),
    );
  }

  /// The line under the frame: on a plate over the camera picture, and a
  /// code that is not the game's as a critical note with its sign.
  Widget _hint(String text) {
    if (_rejected != null) {
      return HorizontNotice(HorizontStatus.critical, child: Text(text));
    }
    return Panel(
      padding: const EdgeInsets.symmetric(
        horizontal: HzSpace.s16,
        vertical: HzSpace.s12,
      ),
      child: Text(text, textAlign: TextAlign.center, style: GameType.body),
    );
  }
}
