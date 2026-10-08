import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../game/space_game.dart';
import '../../net/room.dart';
import '../../net/room_code.dart';
import '../../net/room_directory.dart';
import '../../theme.dart';
import 'room_scanner.dart';

/// Public rooms to join, and a field for the code of a private one.
class RoomList extends StatefulWidget {
  const RoomList({required this.game, super.key});

  final SpaceGame game;

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
        Text('OFFENE RÄUME', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ValueListenableBuilder<List<RoomListing>>(
          valueListenable: widget.game.directory.rooms,
          builder: (context, rooms, _) {
            if (rooms.isEmpty) {
              return const Text(
                'Gerade ist kein öffentlicher Raum offen.',
                style: TextStyle(color: BwColors.textDim, fontSize: 12),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [for (final room in rooms.take(8)) _tile(room)],
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(
              width: 140,
              child: TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                maxLength: 12,
                decoration: const InputDecoration(
                  labelText: 'RAUMCODE',
                  counterText: '',
                ),
                onSubmitted: _join,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _join(_code.text),
              child: const Text('BEITRETEN'),
            ),
          ],
        ),
        // The apps read the QR code of a waiting room with the camera. In
        // the browser the phone camera opens the room link by itself.
        if (!kIsWeb) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('QR-CODE SCANNEN'),
          ),
        ],
      ],
    );
  }

  Widget _tile(RoomListing room) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            room.room,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: BwColors.amber,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${room.host} · ${room.players} '
              '${room.players == 1 ? 'Pilot' : 'Piloten'}'
              '${room.teams ? ' · Teams' : ''}'
              '${room.inMatch ? ' · Gefecht läuft' : ''}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => _join(room.room),
            child: Text(room.inMatch ? 'ZUSEHEN' : 'BEITRETEN'),
          ),
        ],
      ),
    );
  }
}
