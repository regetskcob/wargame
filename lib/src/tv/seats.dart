import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../net/pad_link.dart';
import '../ui/theme.dart';
import '../ui/widgets/panel.dart';
import 'tv_input.dart';

/// Who steers a player's half of the split screen: a controller, a phone
/// paired with the screen, or the device's own keyboard, mouse or touch
/// screen.
@immutable
class DuelSeat {
  const DuelSeat.pad(this.pad, this.kind)
    : phone = null,
      phoneName = '',
      own = false;
  const DuelSeat.phone(String this.phone, this.phoneName)
    : pad = -1,
      kind = TvPadKind.none,
      own = false;
  const DuelSeat.own()
    : pad = -1,
      kind = TvPadKind.none,
      phone = null,
      phoneName = '',
      own = true;

  /// The device's own keyboard and mouse, or its touch screen.
  final bool own;

  /// Index into [TvInput.pads], -1 for a phone.
  final int pad;
  final TvPadKind kind;

  /// Presence id of the phone, null for a controller.
  final String? phone;
  final String phoneName;

  String get label => own
      ? (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.android
            ? 'Touch'
            : tr('Tastatur', 'keyboard'))
      : phone != null
      ? (phoneName.isEmpty ? tr('Handy', 'phone') : phoneName)
      : kind == TvPadKind.gamepad
      ? 'Controller'
      : 'Siri Remote';
}

/// Changes whenever a controller or a phone comes or goes.
abstract final class TvInputSeats {
  static final Listenable listenable = Listenable.merge([
    TvInput.instance.count,
    TvInput.instance.ownInput,
    PadScreen.instance.phones,
  ]);
}

/// Who can play a duel, in the order the halves are handed out: controllers
/// with two sticks first, then phones, the Siri Remote last, as it is
/// always there and the clumsiest to fight with.
List<DuelSeat> duelSeats() {
  final pads = TvInput.instance.pads;
  return [
    // Off the Apple TV the first player may keep their own controls.
    if (!onTv && TvInput.instance.ownInput.value) const DuelSeat.own(),
    for (final (i, pad) in pads.indexed)
      if (pad.kind == TvPadKind.gamepad) DuelSeat.pad(i, pad.kind),
    for (final (id, name) in PadScreen.instance.phones.value)
      DuelSeat.phone(id, name),
    for (final (i, pad) in pads.indexed)
      if (pad.kind == TvPadKind.remote) DuelSeat.pad(i, pad.kind),
  ];
}

/// The colour of each player's half on a split screen: its frame and its
/// name.
const playerColors = [Color(0xFFE5533D), Color(0xFF4A90E2)];

/// Which player a half of a split screen belongs to, and what steers it.
class PlayerTag extends StatelessWidget {
  const PlayerTag({required this.player, required this.seat, super.key});

  final int player;
  final DuelSeat? seat;

  @override
  Widget build(BuildContext context) {
    final seat = this.seat;
    final steer =
        seat?.label ??
        tr(
          'Controller ${player + 1} fehlt',
          'controller ${player + 1} missing',
        );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: BwColors.panel,
        shape: BwShapes.chip(
          edge: seat == null ? BwColors.danger : playerColors[player],
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          '${tr('SPIELER', 'PLAYER')} ${player + 1} · $steer',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: playerColors[player],
          ),
        ),
      ),
    );
  }
}
