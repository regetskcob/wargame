import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../game/space_game.dart';
import '../../net/payloads/lobby_presence.dart';
import '../../net/room.dart';
import '../../theme.dart';
import 'panel.dart';
import '../../l10n/l10n.dart';

/// Waiting room header: the room code, a link to hand around and how many
/// pilots have gathered so far.
class RoomInvite extends StatefulWidget {
  const RoomInvite({required this.game, super.key});

  final SpaceGame game;

  @override
  State<RoomInvite> createState() => _RoomInviteState();
}

class _RoomInviteState extends State<RoomInvite> {
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
            size: 116,
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
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: const Color(0x44000000),
        shape: BwShapes.card(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final code = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('WARTERAUM', 'WAITING ROOM'),
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
                ValueListenableBuilder<List<LobbyPresence>>(
                  valueListenable: widget.game.roster,
                  builder: (context, roster, _) {
                    final waiting = roster
                        .where((m) => !m.inMatch)
                        .length
                        .clamp(1, 999);
                    return Text(
                      waiting == 1
                          ? tr(
                              'Du wartest allein im Raum.',
                              'You are waiting alone in the room.',
                            )
                          : tr(
                              '$waiting Piloten warten im Raum.',
                              '$waiting pilots are waiting in the room.',
                            ),
                      style: const TextStyle(
                        color: BwColors.textDim,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ],
            );
            final invite = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasLink
                      ? tr(
                          'Schick den Link weiter oder lass den QR-Code '
                              'scannen. Wer ihn öffnet, landet hier. Starte, '
                              'sobald alle da sind.',
                          'Pass the link on or have the QR code scanned. '
                              'Whoever opens it lands here. Start as soon '
                              'as everyone is here.',
                        )
                      : tr(
                          'Wer den Raumcode kennt, kann beitreten. Starte, '
                              'sobald alle da sind.',
                          'Anyone who knows the room code can join. Start '
                              'as soon as everyone is here.',
                        ),
                  style: const TextStyle(color: BwColors.textDim, fontSize: 12),
                ),
                if (hasLink) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    color: const Color(0x66000000),
                    child: Text(
                      _link,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _copy,
                          icon: Icon(_copied ? Icons.check : Icons.copy),
                          label: Text(
                            _copied
                                ? tr('KOPIERT', 'COPIED')
                                : tr('KOPIEREN', 'COPY'),
                            maxLines: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Builder(
                          builder: (button) => OutlinedButton.icon(
                            onPressed: () => _share(button),
                            icon: const Icon(Icons.ios_share),
                            label: Text(tr('TEILEN', 'SHARE'), maxLines: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
            final qr = hasLink ? _qr(_link) : null;
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  code,
                  const SizedBox(height: 12),
                  invite,
                  if (qr != null) ...[const SizedBox(height: 12), qr],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 190, child: code),
                const SizedBox(width: 20),
                Expanded(child: invite),
                if (qr != null) ...[const SizedBox(width: 16), qr],
              ],
            );
          },
        ),
      ),
    );
  }
}
