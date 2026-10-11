import '../db/room_registry.dart';

/// A pilot in a room as the host ranking sees them.
typedef RankedPilot = ({
  String id,

  /// Speaks with a key whose hash is the id, so nobody else can.
  bool keyed,

  /// What the presence says, which anybody can write: opened the room,
  /// and when they came.
  bool claimsOwner,
  int? claimedJoin,
});

/// [pilots] from the one who should lead the room to the last, the same
/// on every client that knows the same [order]:
///
/// 1. the owner by the server (the account that opened the room),
/// 2. in rooms without such an owner, opened by a build before keys,
///    whoever claims to own it,
/// 3. pilots with a key the server knows, by when the server saw them,
/// 4. pilots with a key the server does not know (the second player on a
///    screen, who has no session), by when they claim to have come,
/// 5. pilots of builds before keys, by when they claim to have come.
///
/// What a presence claims only counts after everything the server proves,
/// so a player posing as the owner or as the first to come can no longer
/// take the role from those the server knows.
List<String> rankPilots(Iterable<RankedPilot> pilots, RoomOrder order) {
  int tier(RankedPilot pilot) {
    final known = order[pilot.id];
    if (pilot.keyed && known != null) {
      return known.owner ? 0 : 2;
    }
    if (!pilot.keyed && pilot.claimsOwner && !order.hasOwner) {
      return 1;
    }
    return pilot.keyed ? 3 : 4;
  }

  int time(RankedPilot pilot) {
    if (pilot.keyed) {
      if (order[pilot.id] case final known?) {
        return known.joinedAt.millisecondsSinceEpoch;
      }
    }
    final claimed = pilot.claimedJoin;
    // Times from before the game existed only come from clients posing as
    // the first comer.
    return claimed == null || claimed < _gameBorn ? 1 << 53 : claimed;
  }

  final ranked = [...pilots]
    ..sort((a, b) {
      final byTier = tier(a).compareTo(tier(b));
      if (byTier != 0) {
        return byTier;
      }
      // Two owners claiming a room of an older build: the smaller id, as
      // those builds decide it.
      final byTime = tier(a) == 1 ? 0 : time(a).compareTo(time(b));
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
  return [for (final pilot in ranked) pilot.id];
}

/// 2025-01-01, before the first room of the game opened.
const _gameBorn = 1735689600000;
