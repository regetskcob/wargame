import 'dart:async';

import 'package:flutter/material.dart';

import '../../db/room_slots.dart';
import '../../game/game_config.dart';
import '../../l10n/l10n.dart';
import '../theme.dart';
import 'panel.dart';

/// Says so while every room slot of the project is taken, and nothing
/// otherwise. Counts the slots now and every 20 seconds while it shows.
class RoomsBusyNotice extends StatefulWidget {
  const RoomsBusyNotice({required this.slots, this.waiting = false, super.key});

  final RoomSlots slots;

  /// In a waiting room: nobody can come in until a slot is free.
  final bool waiting;

  static const refresh = Duration(seconds: 20);

  @override
  State<RoomsBusyNotice> createState() => _RoomsBusyNoticeState();
}

class _RoomsBusyNoticeState extends State<RoomsBusyNotice> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(widget.slots.count());
    _timer = Timer.periodic(
      RoomsBusyNotice.refresh,
      (_) => unawaited(widget.slots.count()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: RoomSlots.live,
      builder: (context, _, _) {
        if (!RoomSlots.allTaken) {
          return const SizedBox.shrink();
        }
        final rooms = GameConfig.maxRooms;
        final text = widget.waiting
            ? tr(
                'Alle Räume sind gerade belegt: Mitspieler kommen erst in '
                    'deinen Raum, wenn einer frei wird.',
                'All rooms are taken right now: others can only join yours '
                    'once one is free.',
              )
            : tr(
                rooms == 1
                    ? 'Gerade läuft schon ein Mehrspieler-Gefecht, mehr '
                          'trägt der Server im Moment nicht. Einzelspieler '
                          'geht immer, Mitspielen sobald es vorbei ist.'
                    : 'Alle $rooms Mehrspieler-Räume sind gerade belegt. '
                          'Einzelspieler geht immer, Mitspielen sobald einer '
                          'frei wird.',
                rooms == 1
                    ? 'A multiplayer battle is already running, the server '
                          'carries no more right now. Single player always '
                          'works, playing with others once it is over.'
                    : 'All $rooms multiplayer rooms are taken right now. '
                          'Single player always works, playing with others '
                          'once one is free.',
              );
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: const Color(0x66000000),
              shape: BwShapes.card(),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top, color: BwColors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
