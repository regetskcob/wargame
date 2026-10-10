import 'dart:async';

import 'package:flutter/material.dart';

import '../../db/room_slots.dart';
import '../../l10n/l10n.dart';
import '../theme.dart';
import 'panel.dart';

/// Says so while the project's Realtime budget has no room for another
/// room, and nothing otherwise. Counts now and every 20 seconds while it
/// shows.
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
      valueListenable: RoomSlots.load,
      builder: (context, _, _) {
        if (!RoomSlots.allTaken) {
          return const SizedBox.shrink();
        }
        final text = widget.waiting
            ? tr(
                'Alle Räume sind gerade belegt: Mitspieler kommen erst in '
                    'deinen Raum, wenn wieder Platz ist.',
                'All rooms are taken right now: others can only join yours '
                    'once there is room again.',
              )
            : tr(
                'Gerade laufen schon Mehrspieler-Gefechte oder Handy-'
                    'Controller, mehr trägt der Server im Moment nicht. '
                    'Einzelspieler geht immer, Mitspielen sobald wieder '
                    'Platz ist.',
                'Multiplayer battles or phone controllers are running '
                    'already, the server carries no more right now. Single '
                    'player always works, playing with others once there is '
                    'room again.',
              );
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: const Color(0x66000000),
              shape: GameShapes.card(),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top, color: GameColors.amber),
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
