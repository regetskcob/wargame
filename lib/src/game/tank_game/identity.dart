part of '../tank_game.dart';

/// Who may lead the room and whose messages count: every game speaks with
/// a key of its own (`room_key.dart`), and the server keeps who owns the
/// room and when each key came (migration 0020, `host_rank.dart`).
extension TankGameIdentity on TankGame {
  /// [members] from the one who should host the room to the last, or null
  /// while that cannot be told: without a key, or before the server
  /// answered. The room then settles the role through the presences, as
  /// it did before keys.
  List<String>? _rankOf(List<LobbyPresence> members) {
    final order = net.order;
    if (net.key == null || order == null) {
      return null;
    }
    return rankPilots([
      for (final member in members)
        if (member.id == myId)
          (
            id: myId,
            keyed: true,
            claimsOwner: net.isHost,
            claimedJoin: net.joinedAt,
          )
        else
          (
            id: member.id,
            keyed: net.isVerified(member.id),
            claimsOwner: member.owner,
            claimedJoin: member.joinedAt,
          ),
    ], order);
  }

  /// The pilot who should host the room, or null while the presences
  /// settle it, see [_rankOf].
  String? get rightfulHost {
    final members = roster.value;
    final rank = _rankOf(
      members.any((member) => member.id == myId)
          ? members
          : [...members, _presencePayload()],
    );
    return rank == null || rank.isEmpty ? null : rank.first;
  }

  /// Of [a] and [b], who ranks first in the room ([_rankOf]), else the
  /// smaller id, the same on every client.
  String _firstOf(String a, String b) {
    final members = [
      for (final id in [a, b])
        if (id == myId) _presencePayload() else ?_rosterMember(id),
    ];
    final rank = members.length == 2 ? _rankOf(members) : null;
    return rank?.first ?? (a.compareTo(b) <= 0 ? a : b);
  }

  /// The members a room keeps when more than fit: by the ranking once the
  /// server answered, else the owner and the earliest by their presences.
  List<LobbyPresence> _admitted(List<LobbyPresence> all) {
    final max = GameConfig.maxPilots;
    final rank = all.length > max ? _rankOf(all) : null;
    if (rank == null) {
      return LobbyPresence.admitted(all, max);
    }
    final kept = rank.take(max).toSet();
    return [
      for (final member in all)
        if (kept.contains(member.id)) member,
    ];
  }

  /// Whether a message from the channel counts, once its tag was checked
  /// (`NetService.admits`): [claimed] is the id it speaks for, [sender]
  /// who proved to have sent it, null without a valid tag. A message in
  /// the name of a pilot with a key never gets here without their tag.
  bool _admits(NetEvent event, String? claimed, String? sender) {
    final host = rightfulHost;
    if (event == NetEvent.roundStart) {
      // Only the host starts rounds. A host of an older build tags
      // nothing, and while the server has not answered anybody may.
      return host == null || !net.isVerified(host) || sender == host;
    }
    if (claimed == null || claimed == sender) {
      return true;
    }
    // Who runs the CPU tanks, the enemy and the infantry, and speaks for
    // them.
    final runner = round?.botHost ?? host;
    if (sender != null) {
      return sender == runner || sender == host;
    }
    // Without a tag, in the name of an id without a key: a pilot of an
    // older build, or a CPU tank of a runner of an older build.
    if (_rosterMember(claimed) != null) {
      return true;
    }
    return runner == null || !net.isVerified(runner);
  }
}
