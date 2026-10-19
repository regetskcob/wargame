import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../../db/room_slots.dart';
import '../../game/game_config.dart';
import '../../game/tank_game.dart';
import '../../net/room.dart';
import '../../net/room_code.dart';
import '../../net/room_directory.dart';
import '../theme.dart';
import 'room_scanner.dart';
import '../../l10n/l10n.dart';
import '../../tv/select_to_type.dart';
import '../../tv/tv_input.dart';

/// Public rooms to join, and a field for the code of a private one.
class RoomList extends StatefulWidget {
  const RoomList({required this.game, super.key});

  final TankGame game;

  @override
  State<RoomList> createState() => _RoomListState();
}

class _RoomListState extends State<RoomList> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _join(String room) {
    // A pasted room link works as well as the bare code.
    final code = roomCodeFrom(room);
    if (code == null || code == widget.game.net.room) {
      return;
    }
    joinRoom(code);
  }

  Future<void> _scan() async {
    final code = await RoomScanner.scan(context);
    if (code != null) {
      _join(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Kennung(tr('Offene Räume', 'Open rooms')),
        const SizedBox(height: HzSpace.s8),
        ListenableBuilder(
          listenable: Listenable.merge([
            widget.game.directory.rooms,
            RoomSlots.load,
          ]),
          builder: (context, _) {
            final rooms = widget.game.directory.rooms.value;
            if (rooms.isEmpty) {
              return Text(
                tr(
                  'Gerade ist kein öffentlicher Raum offen.',
                  'There is no public room open right now.',
                ),
                style: GameType.caption,
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [for (final room in rooms.take(8)) _tile(room)],
            );
          },
        ),
        const SizedBox(height: HzSpace.s12),
        // Scan, code and join without frames, so only the field stands out.
        Row(
          children: [
            // The apps read the QR code of a waiting room with the camera. In
            // the browser the phone camera opens the room link by itself, and
            // the Apple TV has no camera.
            if (!kIsWeb && !onTv) ...[
              IconButton(
                onPressed: _scan,
                tooltip: tr('QR-Code scannen', 'Scan QR code'),
                color: GameColors.text,
                icon: Icon(
                  Icons.qr_code_scanner_outlined,
                  semanticLabel: tr('QR-Code scannen', 'Scan QR code'),
                ),
              ),
              const SizedBox(width: HzSpace.s4),
            ],
            Expanded(
              child: SelectToType(
                builder: (focusNode, readOnly) => TextField(
                  focusNode: focusNode,
                  readOnly: readOnly,
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 12,
                  // Horizont keeps labels out of the frame: the hint names
                  // the field, the code itself is set in mono.
                  style: GameType.data.copyWith(letterSpacing: 0.08 * 14),
                  decoration: InputDecoration(
                    hintText: tr('RAUMCODE', 'ROOM CODE'),
                    counterText: '',
                  ),
                  onSubmitted: _join,
                ),
              ),
            ),
            const SizedBox(width: HzSpace.s4),
            TextButton(
              onPressed: () => _join(_code.text),
              style: TextButton.styleFrom(foregroundColor: GameColors.text),
              child: Text(tr('BEITRETEN', 'JOIN')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tile(RoomListing room) {
    final full = room.players >= GameConfig.maxPilots;
    // A room of one holds no slot yet: joining needs a free one.
    final taken = RoomSlots.allTaken && room.players < 2;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HzSpace.s2),
      child: Row(
        children: [
          Text(
            room.room,
            style: GameType.data.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: HzSpace.s12),
          Expanded(
            child: Text(
              '${room.host} · ${room.players} '
              '${room.players == 1 ? tr('Pilot', 'pilot') : tr('Piloten', 'pilots')}'
              '${room.teams ? ' · Teams' : ''}'
              '${room.inMatch ? tr(' · Gefecht läuft', ' · battle in progress') : ''}',
              overflow: TextOverflow.ellipsis,
              style: GameType.caption,
            ),
          ),
          TextButton(
            onPressed: full || taken ? null : () => _join(room.room),
            child: Text(
              full
                  ? tr('VOLL', 'FULL')
                  : taken
                  ? tr('BELEGT', 'TAKEN')
                  : room.inMatch
                  ? tr('ZUSEHEN', 'WATCH')
                  : tr('BEITRETEN', 'JOIN'),
            ),
          ),
        ],
      ),
    );
  }
}
