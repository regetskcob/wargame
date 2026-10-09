import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../game/tank_game.dart';
import '../../game/game_mode.dart';
import '../../net/room.dart';
import '../theme.dart';
import 'choice_row.dart';
import 'panel.dart';
import '../../l10n/l10n.dart';

/// The room code, the link to hand around and its QR code.
class RoomInvite extends StatefulWidget {
  const RoomInvite({required this.game, super.key});

  final TankGame game;

  @override
  State<RoomInvite> createState() => _RoomInviteState();
}

class _RoomInviteState extends State<RoomInvite> {
  /// One height for every button in the box, so the rows line up.
  static const _buttonHeight = 48.0;

  bool _copied = false;
  Timer? _reset;

  String get _room => widget.game.net.room;
  String get _link => roomLink(_room);

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _link));
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  Future<void> _share(BuildContext button) async {
    // An iPad points its share sheet at the button.
    final box = button.findRenderObject() as RenderBox?;
    final shared = await shareRoomLink(
      _link,
      tr(
        'Komm ins Panzergefecht, Raum $_room.',
        'Join the Panzergefecht, room $_room.',
      ),
      origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
    if (!shared) {
      await _copy();
    }
  }

  /// The link as a code to scan with a phone camera, on white for contrast.
  Widget _qr(String link) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(8),
          child: QrImageView(
            data: link,
            size: 84,
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
        const SizedBox(height: 4),
        Text(
          tr('ZUM SCANNEN', 'TO SCAN'),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.5,
            color: BwColors.textDim,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLink = _link.isNotEmpty;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tr('EINLADEN', 'INVITE'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        SelectableText(
          _room,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            color: BwColors.sand,
          ),
        ),
        const SizedBox(height: 8),
        if (hasLink)
          Wrap(
            spacing: 4,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _copy,
                // Narrower than the theme so the share icon fits beside it
                // next to the QR code on a phone.
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, _buttonHeight),
                  maximumSize: const Size(double.infinity, _buttonHeight),
                ),
                icon: Icon(_copied ? Icons.check : Icons.copy),
                label: Text(
                  _copied ? tr('KOPIERT', 'COPIED') : tr('KOPIEREN', 'COPY'),
                  maxLines: 1,
                ),
              ),
              Builder(
                builder: (button) => IconButton(
                  onPressed: () => _share(button),
                  tooltip: tr('Teilen', 'Share'),
                  color: BwColors.sand,
                  constraints: const BoxConstraints.tightFor(
                    width: _buttonHeight,
                    height: _buttonHeight,
                  ),
                  icon: Icon(
                    Icons.ios_share,
                    semanticLabel: tr('Teilen', 'Share'),
                  ),
                ),
              ),
            ],
          )
        else
          Text(
            tr(
              'Wer den Raumcode kennt, kann beitreten.',
              'Anyone who knows the room code can join.',
            ),
            style: const TextStyle(color: BwColors.textDim, fontSize: 12),
          ),
      ],
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: const Color(0x44000000),
        shape: BwShapes.card(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: details),
                if (hasLink) ...[const SizedBox(width: 12), _qr(_link)],
              ],
            ),
            // Only rounds against each other show up in the room list.
            if (hasLink && widget.game.mode.value == GameMode.multi) ...[
              const SizedBox(height: 10),
              ValueListenableBuilder<bool>(
                valueListenable: widget.game.publicRoom,
                builder: (context, public, _) => ChoiceRow<bool>(
                  options: [
                    (false, tr('PRIVAT', 'PRIVATE'), null),
                    (true, tr('ÖFFENTLICH', 'PUBLIC'), null),
                  ],
                  selected: public,
                  onSelected: (v) => widget.game.publicRoom.value = v ?? false,
                  expand: true,
                  minHeight: _buttonHeight,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
