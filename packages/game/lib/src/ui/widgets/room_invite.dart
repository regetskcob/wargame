import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/space_game.dart';
import '../../net/payloads/lobby_presence.dart';
import '../../net/room.dart';
import '../../theme.dart';

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

  Future<void> _share() async {
    final shared = await shareRoomLink(
      _link,
      'Komm ins Panzergefecht, Raum $_room.',
    );
    if (!shared) {
      await _copy();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLink = _link.isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x44000000),
        border: Border.all(color: BwColors.oliveLight),
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
                  'WARTERAUM',
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
                          ? 'Du wartest allein im Raum.'
                          : '$waiting Piloten warten im Raum.',
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
                      ? 'Schick den Link weiter. Wer ihn öffnet, landet hier. '
                            'Starte, sobald alle da sind.'
                      : 'Wer den Raumcode kennt, kann beitreten. Starte, '
                            'sobald alle da sind.',
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
                    child: SelectableText(
                      _link,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _copy,
                        icon: Icon(_copied ? Icons.check : Icons.copy),
                        label: Text(_copied ? 'KOPIERT' : 'LINK KOPIEREN'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _share,
                        icon: const Icon(Icons.ios_share),
                        label: const Text('TEILEN'),
                      ),
                    ],
                  ),
                ],
              ],
            );
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [code, const SizedBox(height: 12), invite],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 190, child: code),
                const SizedBox(width: 20),
                Expanded(child: invite),
              ],
            );
          },
        ),
      ),
    );
  }
}
