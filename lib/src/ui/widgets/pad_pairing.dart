import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../game/tank_game.dart';
import '../../net/pad_link.dart';
import '../controller_view.dart';
import '../theme.dart';
import 'panel.dart';
import 'room_scanner.dart';
import 'tablet_scale.dart';
import '../../l10n/l10n.dart';
import '../../tv/tv_input.dart';

/// Part of the account sheet: pair a phone as the gamepad of this screen,
/// or, on a phone, become the gamepad of another one.
class ControllerSection extends StatelessWidget {
  const ControllerSection({required this.game, super.key});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    // The Apple TV is a screen like the browser.
    final phoneApp =
        !kIsWeb &&
        !onTv &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    // The browser and the tablets show the game, phones in the app steer
    // it. A tablet in the app can do both.
    final screen =
        !phoneApp || MediaQuery.sizeOf(context).shortestSide >= tabletShortSide;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('CONTROLLER', 'CONTROLLER'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        if (screen) _ScreenPairing(game: game),
        if (screen && phoneApp) const SizedBox(height: 14),
        if (phoneApp) _BecomePad(game: game),
      ],
    );
  }
}

/// The screen's side: a button that shows the code, or the paired phone.
class _ScreenPairing extends StatelessWidget {
  const _ScreenPairing({required this.game});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    final pad = PadScreen.instance;
    return ValueListenableBuilder<String?>(
      valueListenable: pad.paired,
      builder: (context, paired, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            paired != null
                ? tr(
                    'Gekoppelt mit ${paired.isEmpty ? 'einem Handy' : paired}. '
                        'Die Sticks des Handys steuern deinen Panzer hier.',
                    'Paired with ${paired.isEmpty ? 'a phone' : paired}. The '
                        'sticks of the phone steer your tank here.',
                  )
                : tr(
                    'Steuere deinen Panzer hier mit dem Handy: Koppeln '
                        'öffnet einen QR-Code, den du mit der Panzergefecht-'
                        'App oder der Handykamera scannst.',
                    'Steer your tank here with your phone: pairing shows a '
                        'QR code to scan with the Panzergefecht app or the '
                        'phone camera.',
                  ),
            style: const TextStyle(color: BwColors.textDim, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => PadPairingDialog.show(context),
                icon: const Icon(Icons.qr_code_2),
                label: Text(
                  paired != null
                      ? tr('CODE ZEIGEN', 'SHOW CODE')
                      : tr('HANDY KOPPELN', 'PAIR PHONE'),
                ),
              ),
              if (paired != null)
                OutlinedButton.icon(
                  onPressed: () => unawaited(pad.close()),
                  icon: const Icon(Icons.link_off),
                  label: Text(tr('TRENNEN', 'UNPAIR')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The phone's side: scan the screen's code, or type it.
class _BecomePad extends StatelessWidget {
  const _BecomePad({required this.game});

  final TankGame game;

  Future<void> _scan(BuildContext context) async {
    final code = await RoomScanner.scanPad(context);
    if (code != null && context.mounted) {
      await ControllerView.open(context, code, game.myName);
    }
  }

  Future<void> _type(BuildContext context) async {
    final code = await showDialog<String>(
      context: context,
      builder: (context) => const _CodeDialog(),
    );
    if (code != null && context.mounted) {
      await ControllerView.open(context, code, game.myName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(
            'Nutze dieses Gerät als Controller für das Spiel im Browser am '
                'PC oder Tablet. Öffne dort Konto, tippe auf Handy koppeln '
                'und scanne den QR-Code.',
            'Use this device as a controller for the game in the browser on '
                'a computer or tablet. Open the account there, tap Pair '
                'phone and scan the QR code.',
          ),
          style: const TextStyle(color: BwColors.textDim, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => _scan(context),
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(tr('ALS CONTROLLER NUTZEN', 'USE AS CONTROLLER')),
            ),
            TextButton(
              onPressed: () => _type(context),
              child: Text(tr('CODE EINGEBEN', 'ENTER CODE')),
            ),
          ],
        ),
      ],
    );
  }
}

class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _field = TextEditingController();
  var _wrong = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    final code = padCodeFrom(_field.text);
    if (code == null) {
      setState(() => _wrong = true);
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BwColors.surface,
      title: Text(tr('KOPPLUNGSCODE', 'PAIRING CODE')),
      content: TextField(
        controller: _field,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          hintText: tr('8 Zeichen', '8 characters'),
          errorText: _wrong
              ? tr(
                  'Der Code hat $padCodeLength Zeichen.',
                  'The code has $padCodeLength characters.',
                )
              : null,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('ABBRECHEN', 'CANCEL')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(tr('VERBINDEN', 'CONNECT')),
        ),
      ],
    );
  }
}

/// The QR code and the pairing code of this screen, and whether a phone
/// came in. Opening it opens the pairing.
class PadPairingDialog extends StatefulWidget {
  const PadPairingDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: const PadPairingDialog(),
        ),
      ),
    );
  }

  @override
  State<PadPairingDialog> createState() => _PadPairingDialogState();
}

class _PadPairingDialogState extends State<PadPairingDialog> {
  final _pad = PadScreen.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_pad.open());
    _pad.paired.addListener(_closeOnPair);
  }

  /// Once the phone is in, the dialog has done its job.
  void _closeOnPair() {
    if (_pad.paired.value != null && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    _pad.paired.removeListener(_closeOnPair);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: ValueListenableBuilder<String?>(
        valueListenable: _pad.code,
        builder: (context, code, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('HANDY KOPPELN', 'PAIR PHONE'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: tr('Schließen', 'Close'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                tr(
                  'Scanne den Code mit der Panzergefecht-App (Konto, Als '
                      'Controller nutzen) oder mit der Kamera des Handys. Das '
                      'Handy wird dann zum Gamepad für diesen Bildschirm.',
                  'Scan the code with the Panzergefecht app (Account, Use '
                      'as controller) or the phone camera. The phone then '
                      'becomes the gamepad of this screen.',
                ),
                style: const TextStyle(color: BwColors.textDim, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            if (code == null)
              const Center(child: CircularProgressIndicator())
            else
              Center(
                child: Column(
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(10),
                      child: QrImageView(
                        data: padLink(code),
                        size: 200,
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF11140C),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF11140C),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      spacedPadCode(code),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 5,
                        color: BwColors.sand,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ValueListenableBuilder<String?>(
                      valueListenable: _pad.paired,
                      builder: (context, paired, _) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (paired == null)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: BwColors.amber,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            paired == null
                                ? tr(
                                    'Warte auf das Handy …',
                                    'Waiting for the phone …',
                                  )
                                : tr('Handy gekoppelt', 'Phone paired'),
                            style: const TextStyle(
                              color: BwColors.textDim,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  unawaited(_pad.close());
                  Navigator.of(context).pop();
                },
                child: Text(tr('KOPPLUNG BEENDEN', 'END PAIRING')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
