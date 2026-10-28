import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../game/tank_game.dart';
import '../../net/pad_link.dart';
import '../controller_view.dart';
import '../theme.dart';
import 'game_dialog.dart';
import 'notice.dart';
import 'panel.dart';
import 'room_scanner.dart';
import 'tablet_scale.dart';
import '../../l10n/l10n.dart';
import '../../tv/tv_input.dart';

/// Part of the account sheet: pair a phone as the gamepad of this screen,
/// or, on a phone, become the gamepad of another one.
class ControllerSection extends StatelessWidget {
  const ControllerSection({required this.game, this.heading = true, super.key});

  final TankGame game;

  /// Off where the surrounding box already names the section.
  final bool heading;

  @override
  Widget build(BuildContext context) {
    // Only a phone in the app steers a game elsewhere. The browser, the
    // tablets and the Apple TV show the game and pair a phone.
    final phone =
        !kIsWeb &&
        !onTv &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android) &&
        MediaQuery.sizeOf(context).shortestSide < tabletShortSide;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (heading) ...[
          Kennung(tr('CONTROLLER', 'CONTROLLER')),
          const SizedBox(height: HzSpace.s8),
        ],
        if (phone) _BecomePad(game: game) else _ScreenPairing(game: game),
      ],
    );
  }
}

/// The help line under a section heading.
final _help = GameType.callout.copyWith(color: GameColors.textMuted);

/// Says so while the Realtime budget leaves no room for the paired phones,
/// and nothing otherwise.
class PadBusyNotice extends StatelessWidget {
  const PadBusyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PadScreen.instance.busy,
      builder: (context, busy, _) => busy
          ? Padding(
              padding: const EdgeInsets.only(top: HzSpace.s8),
              child: Notice(
                HorizontStatus.warning,
                child: Text(
                  tr(
                    'Gerade ist kein Platz für Handy-Controller: Der Server ist '
                        'mit anderen Gefechten ausgelastet. Das Handy steuert, '
                        'sobald wieder Platz ist; Controller und Tastatur gehen '
                        'immer.',
                    'There is no room for phone controllers right now: the '
                        'server is busy with other battles. The phone steers '
                        'once there is room again; controllers and keyboard '
                        'always work.',
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
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
                        'App auf dem Handy scannst.',
                    'Steer your tank here with your phone: pairing shows a '
                        'QR code to scan with the Panzergefecht app on the '
                        'phone.',
                  ),
            style: _help,
          ),
          const PadBusyNotice(),
          const SizedBox(height: HzSpace.s12),
          Wrap(
            spacing: HzSpace.s8,
            runSpacing: HzSpace.s8,
            children: [
              FilledButton.icon(
                onPressed: () => PadPairingDialog.show(context),
                icon: const Icon(HorizontSymbols.qrCode2),
                label: Text(
                  paired != null
                      ? tr('CODE ZEIGEN', 'SHOW CODE')
                      : tr('HANDY KOPPELN', 'PAIR PHONE'),
                ),
              ),
              if (paired != null)
                OutlinedButton.icon(
                  onPressed: () => unawaited(pad.close()),
                  icon: const Icon(HorizontSymbols.linkOff),
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
    final code = await showGameDialog<String>(
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
          style: _help,
        ),
        const SizedBox(height: HzSpace.s12),
        Wrap(
          spacing: HzSpace.s8,
          runSpacing: HzSpace.s8,
          children: [
            FilledButton.icon(
              onPressed: () => _scan(context),
              icon: const Icon(HorizontSymbols.qrCodeScanner),
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
    return AlertDialog.adaptive(
      title: Text(tr('KOPPLUNGSCODE', 'PAIRING CODE')),
      // The Cupertino dialog on iOS and macOS has no Material for the field.
      content: Material(
        type: MaterialType.transparency,
        child: TextField(
          controller: _field,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: GameType.data,
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
      ),
      actions: [
        horizontDialogAction(
          context,
          label: tr('ABBRECHEN', 'CANCEL'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        horizontDialogAction(
          context,
          label: tr('VERBINDEN', 'CONNECT'),
          primary: true,
          onPressed: _submit,
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
        insetPadding: const EdgeInsets.all(HzSpace.s16),
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
      padding: const EdgeInsets.fromLTRB(
        HzSpace.s24,
        HzSpace.s16,
        HzSpace.s12,
        HzSpace.s16,
      ),
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
                    style: GameType.title,
                  ),
                ),
                IconButton(
                  tooltip: tr('Schließen', 'Close'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(HorizontSymbols.close),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: HzSpace.s8),
              child: Text(
                tr(
                  'Scanne den Code mit der Panzergefecht-App auf dem Handy '
                      '(Konto, Als Controller nutzen). Das Handy wird dann zum '
                      'Gamepad für diesen Bildschirm.',
                  'Scan the code with the Panzergefecht app on the phone '
                      '(Account, Use as controller). The phone then becomes '
                      'the gamepad of this screen.',
                ),
                style: _help,
              ),
            ),
            const SizedBox(height: HzSpace.s16),
            if (code == null)
              const Center(child: CircularProgressIndicator())
            else
              Center(
                child: Column(
                  children: [
                    // A camera needs dark modules on a light ground with a
                    // quiet zone: ink as the ground, the sunken surface as
                    // the modules.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: GameColors.text,
                        borderRadius: BorderRadius.circular(HzRadius.r6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(HzSpace.s12),
                        child: QrImageView(
                          data: padLink(code),
                          size: 200,
                          padding: EdgeInsets.zero,
                          backgroundColor: GameColors.text,
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                          eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: GameColors.sunken,
                          ),
                          dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: GameColors.sunken,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: HzSpace.s12),
                    SelectableText(
                      spacedPadCode(code),
                      style: GameType.dataLarge.copyWith(letterSpacing: 4),
                    ),
                    const SizedBox(height: HzSpace.s8),
                    ValueListenableBuilder<String?>(
                      valueListenable: _pad.paired,
                      builder: (context, paired, _) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (paired == null)
                            const SizedBox(
                              width: HzIconSize.inline,
                              height: HzIconSize.inline,
                              child: CircularProgressIndicator(
                                strokeWidth: HzLine.selection,
                              ),
                            )
                          else
                            Icon(
                              HorizontStatus.positive.icon,
                              size: HzIconSize.inline,
                              color: GameColors.positive,
                            ),
                          const SizedBox(width: HzSpace.s8),
                          Text(
                            paired == null
                                ? tr(
                                    'Warte auf das Handy …',
                                    'Waiting for the phone …',
                                  )
                                : tr('Handy gekoppelt', 'Phone paired'),
                            style: GameType.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: HzSpace.s8),
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
