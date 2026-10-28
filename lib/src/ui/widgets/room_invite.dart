import 'dart:async';

import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';
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

  /// The link as a code to scan with a phone camera: dark modules on the
  /// ink colour, the strongest contrast the palette has, in a radius-6 box.
  Widget _qr(String link) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: GameColors.text,
            borderRadius: BorderRadius.circular(HzRadius.r6),
          ),
          padding: const EdgeInsets.all(HzSpace.s8),
          child: QrImageView(
            data: link,
            size: 84,
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
        const SizedBox(height: HzSpace.s4),
        Text(tr('ZUM SCANNEN', 'TO SCAN'), style: GameType.kennung),
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
        Kennung(tr('Einladen · Code', 'Invite · code')),
        const SizedBox(height: HzSpace.s4),
        // The code big in mono: read aloud across a room or typed in.
        SelectableText(
          _room,
          style: GameType.dataLarge.copyWith(
            fontSize: 32,
            height: 40 / 32,
            letterSpacing: 0.12 * 32,
          ),
        ),
        const SizedBox(height: HzSpace.s8),
        if (hasLink)
          Wrap(
            spacing: 4,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _copy,
                // Plain ink like the share icon beside it, and narrow enough
                // that both fit next to the QR code on a phone.
                style: TextButton.styleFrom(
                  foregroundColor: GameColors.text,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, _buttonHeight),
                  maximumSize: const Size(double.infinity, _buttonHeight),
                ),
                icon: Icon(
                  _copied ? HorizontSymbols.check : HorizontSymbols.contentCopy,
                ),
                label: Text(
                  _copied ? tr('KOPIERT', 'COPIED') : tr('KOPIEREN', 'COPY'),
                  maxLines: 1,
                ),
              ),
              Builder(
                builder: (button) => IconButton(
                  onPressed: () => _share(button),
                  tooltip: tr('Teilen', 'Share'),
                  color: GameColors.text,
                  constraints: const BoxConstraints.tightFor(
                    width: _buttonHeight,
                    height: _buttonHeight,
                  ),
                  icon: Icon(
                    HorizontSymbols.iosShare,
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
            style: GameType.caption,
          ),
      ],
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: GameColors.sunken,
        shape: GameShapes.card(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(HzSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: details),
                if (hasLink) ...[
                  const SizedBox(width: HzSpace.s12),
                  _qr(_link),
                ],
              ],
            ),
            // Only rounds against each other show up in the room list.
            if (hasLink &&
                (widget.game.mode.value == GameMode.multi ||
                    widget.game.mode.value == GameMode.flag)) ...[
              const SizedBox(height: HzSpace.s12),
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
