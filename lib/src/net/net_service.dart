import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'net_events.dart';
import 'payloads/death_payload.dart';
import 'payloads/defense_payload.dart';
import 'payloads/hit_payload.dart';
import 'payloads/lobby_presence.dart';
import 'payloads/obstacle_payload.dart';
import 'payloads/soldier_payload.dart';
import 'payloads/special_payload.dart';
import 'payloads/power_up_payload.dart';
import 'payloads/round_start_payload.dart';
import 'payloads/tank_state_payload.dart';
import 'payloads/shoot_payload.dart';
import 'payloads/strike_payload.dart';
import 'presence_throttle.dart';
import 'replay.dart';

class NetService {
  NetService({
    required this.myId,
    required this.room,
    this.isHost = true,
    SupabaseClient? client,
  }) : _ownClient = client;

  /// A connection of its own, for a second player on the same device: one
  /// connection joins a room's channel only once.
  final SupabaseClient? _ownClient;

  final String myId;

  /// Code of the room whose channel this connects to.
  final String room;

  /// Whether this player opened the room. Others only join and play. The
  /// game hands the role on from there.
  final bool isHost;

  void Function(TankStatePayload payload)? onTankState;
  void Function(TankStatesPayload payload)? onTankStates;
  void Function(ShootPayload payload)? onShoot;
  void Function(HitPayload payload)? onHit;
  void Function(DeathPayload payload)? onDeath;
  void Function(PickupPayload payload)? onPickup;
  void Function(SmokePayload payload)? onSmoke;
  void Function(ObstaclePayload payload)? onObstacle;
  void Function(SoldierPayload payload)? onSoldier;
  void Function(MinePayload payload)? onMine;
  void Function(ArtilleryPayload payload)? onArtillery;
  void Function(DefensePayload payload)? onDefense;
  void Function(TowerPayload payload)? onTower;
  void Function(TroopsPayload payload)? onTroops;
  void Function(GrenadePayload payload)? onGrenade;
  void Function(DronePayload payload)? onDrone;
  void Function(BlastPayload payload)? onBlast;
  void Function(AirPayload payload)? onAir;
  void Function(SquadPayload payload)? onSquad;
  void Function(UsePayload payload)? onUse;
  void Function(RoundStartPayload payload)? onRoundStart;
  void Function(List<LobbyPresence> roster)? onRosterChanged;
  void Function(String id)? onPeerLeft;

  /// Ids that more than one presence in the room claims: somebody poses
  /// as another player.
  Set<String> duplicateIds = const {};

  /// Keeps the messages of the current round for a replay.
  ReplayRecorder? recorder;

  /// While a replay runs, the game neither sends nor hears match messages.
  /// The waiting room and round starts still come through.
  bool muted = false;

  /// The host closed the room. Carries the id of who sent it.
  void Function(String id)? onClose;

  RealtimeChannel? _channel;
  PresenceThrottle? _presence;
  int? _joinedAt;

  /// When this player came into the room. Stays through reconnects, and
  /// starts afresh once the room was left.
  int get joinedAt => _joinedAt ??= DateTime.now().millisecondsSinceEpoch;
  LobbyPresence? _me;

  /// Whether anybody else is in the room. Alone, nothing is sent: nobody
  /// would hear it, and every message counts against the project's limit
  /// of messages per second, which closes all channels once it is hit.
  @visibleForTesting
  bool othersPresent = false;
  bool _disposed = false;
  final _subscriptions = <StreamSubscription<void>>[];

  SupabaseClient get _client => _ownClient ?? Supabase.instance.client;

  Future<void> connect(LobbyPresence me) async {
    _disposed = false;
    _me = me;
    final link = this.link;
    if (link != null && identical(link.guest, this)) {
      // A second player on this device: no channel, the first player's
      // game hands everything on.
      _registerHandlers(null);
      link._guestIn = true;
      link.host._retrack();
      link.host._emitRoster();
      return;
    }
    final channel = _client.channel(
      'game-arena-$room',
      options: const RealtimeChannelConfig(self: false),
    );
    _channel = channel;
    _presence = PresenceThrottle(channel);
    _registerHandlers(channel);
    _subscriptions.add(channel.onPresenceSync.listen((_) => _emitRoster()));
    _subscriptions.add(channel.onPresenceJoin.listen((_) => _emitRoster()));
    _subscriptions.add(
      channel.onPresenceLeave.listen((leave) {
        final remainingIds = <String>{
          for (final state in channel.presenceState())
            for (final presence in state.presences)
              if (presence.payload['id'] is String)
                presence.payload['id'] as String,
        };
        for (final presence in leave.leftPresences) {
          final id = presence.payload['id'] as String?;
          if (id != null && id != myId && !remainingIds.contains(id)) {
            onPeerLeft?.call(id);
          }
        }
        _emitRoster();
      }),
    );
    _subscriptions.add(
      channel.onStatusChange.listen((change) {
        if (change.status == RealtimeSubscribeStatus.subscribed) {
          final me = _me;
          if (me != null) {
            _presence?.track(_tracked(me));
          }
        } else if (change.status == RealtimeSubscribeStatus.channelError ||
            change.status == RealtimeSubscribeStatus.closed) {
          _scheduleReconnect();
        }
      }),
    );
    channel.subscribe();
  }

  /// What every event does when it comes in, from the channel or from the
  /// other player's game on this device.
  void _registerHandlers(RealtimeChannel? channel) {
    _listen(
      channel,
      NetEvent.state,
      (json) => onTankState?.call(TankStatePayload.fromJson(json)),
    );
    _listen(
      channel,
      NetEvent.states,
      (json) => onTankStates?.call(TankStatesPayload.fromJson(json)),
    );
    _listen(
      channel,
      NetEvent.shoot,
      (json) => onShoot?.call(ShootPayload.fromJson(json)),
    );
    _listen(
      channel,
      NetEvent.hit,
      (json) => onHit?.call(HitPayload.fromJson(json)),
    );
    _listen(
      channel,
      NetEvent.death,
      (json) => onDeath?.call(DeathPayload.fromJson(json)),
    );
    _listen(
      channel,
      NetEvent.soldier,
      (json) => onSoldier?.call(SoldierPayload.fromJson(json)),
    );
    _listen(
      channel,
      NetEvent.grenade,
      (json) => onGrenade?.call(GrenadePayload.fromJson(json)),
    );
    _listen(
      channel,
      NetEvent.drone,
      (json) => onDrone?.call(DronePayload.fromJson(json)),
    );
    _listen(
      channel,
      NetEvent.blast,
      (json) => onBlast?.call(BlastPayload.fromJson(json)),
    );
    _listen(
      channel,
      NetEvent.air,
      (json) => onAir?.call(AirPayload.fromJson(json)),
    );
    _listen(
      channel,
      NetEvent.squad,
      (json) => onSquad?.call(SquadPayload.fromJson(json)),
    );
    _listen(
      channel,
      NetEvent.use,
      (json) => onUse?.call(UsePayload.fromJson(json)),
    );
    _listen(
      channel,
      NetEvent.obstacle,
      (json) => onObstacle?.call(ObstaclePayload.fromJson(json)),
    );
    _listen(
      channel,
      NetEvent.pickup,
      (json) => onPickup?.call(PickupPayload.fromJson(json)),
    );
    _listen(
      channel,
      NetEvent.mine,
      (json) => onMine?.call(MinePayload.fromJson(json)),
    );
    _listen(
      channel,
      NetEvent.artillery,
      (json) => onArtillery?.call(ArtilleryPayload.fromJson(json)),
    );
    _listen(
      channel,
      NetEvent.smoke,
      (json) => onSmoke?.call(SmokePayload.fromJson(json)),
    );
    _listen(
      channel,
      NetEvent.defense,
      (json) => onDefense?.call(DefensePayload.fromJson(json)),
    );
    _listen(
      channel,
      NetEvent.tower,
      (json) => onTower?.call(TowerPayload.fromJson(json)),
    );
    _listen(channel, NetEvent.troops, (json) {
      final payload = TroopsPayload.tryParse(json);
      if (payload != null) {
        onTroops?.call(payload);
      }
    });
    _listen(
      channel,
      NetEvent.close,
      (json) => onClose?.call(json['id'] as String),
    );
    _listen(
      channel,
      NetEvent.roundStart,
      (json) => onRoundStart?.call(RoundStartPayload.fromJson(json)),
    );
  }

  final _handlers = <NetEvent, void Function(Map<String, dynamic> json)>{};

  void _listen(
    RealtimeChannel? channel,
    NetEvent event,
    void Function(Map<String, dynamic> json) handler,
  ) {
    _handlers[event] = handler;
    if (channel == null) {
      return;
    }
    _subscriptions.add(
      channel.onBroadcast(event: event.name).listen((json) {
        _deliver(event, json);
        // The second player on this device hears what came in as well.
        final link = this.link;
        if (link != null && link._guestIn && identical(link.host, this)) {
          link.guest._deliver(event, json);
        }
      }),
    );
  }

  /// One message that came in.
  void _deliver(NetEvent event, Map<String, dynamic> json) {
    final roundStart = event == NetEvent.roundStart;
    // Round starts come through a replay as well, and are not part of it.
    if (json['id'] == myId || (muted && !roundStart)) {
      return;
    }
    final handler = _handlers[event];
    if (handler == null) {
      return;
    }
    // Anybody can send anything on the channel: a message that does not
    // parse is dropped instead of breaking off the game half way.
    try {
      handler(json);
    } on Object catch (error) {
      debugPrint('Dropped ${event.name} message: $error');
      return;
    }
    if (!roundStart) {
      recorder?.add(event, json);
    }
  }

  void _scheduleReconnect() {
    if (_disposed) {
      return;
    }
    final me = _me;
    if (me == null) {
      return;
    }
    Timer(const Duration(seconds: 2), () async {
      if (_disposed) {
        return;
      }
      await _teardownChannel();
      await connect(me);
    });
  }

  void send(NetEvent event, Map<String, dynamic> payload) {
    if (muted) {
      return;
    }
    recorder?.add(event, payload);
    final link = this.link;
    final peer = link?.peerOf(this);
    if (peer != null && link!._guestIn) {
      // The other player on this device, without a round trip.
      final copy = Map<String, dynamic>.of(payload);
      scheduleMicrotask(() => peer._deliver(event, copy));
    }
    if (!othersPresent) {
      return;
    }
    transmit(event, payload);
  }

  /// Puts one message on the channel.
  @protected
  void transmit(NetEvent event, Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) {
      return;
    }
    unawaited(
      channel.sendBroadcastMessage(event: event.name, payload: payload),
    );
  }

  Future<void> updatePresence(LobbyPresence me) async {
    _me = me;
    _presence?.track(_tracked(me));
    final link = this.link;
    if (link != null && identical(link.guest, this)) {
      link.host._retrack();
      link.host._emitRoster();
    }
  }

  void _emitRoster() {
    final channel = _channel;
    if (channel == null) {
      return;
    }
    final byId = <String, LobbyPresence>{};
    final seen = <String>{};
    final twice = <String>{};
    final carried = <LobbyPresence>[];
    for (final state in channel.presenceState()) {
      for (final presence in state.presences) {
        final member = LobbyPresence.tryParse(presence.payload);
        if (member == null) {
          continue;
        }
        if (!seen.add(member.id)) {
          twice.add(member.id);
        }
        byId[member.id] = member;
        // A second player on that device, who has no presence of their own.
        final local = presence.payload['local'];
        final guest = local is Map<String, dynamic>
            ? LobbyPresence.tryParse(local)
            : null;
        if (guest != null) {
          carried.add(guest);
        }
      }
    }
    duplicateIds = twice;
    // Only people on other devices count: nothing goes over the channel
    // for the second player on this one.
    othersPresent = byId.keys.any((id) => id != myId);
    for (final guest in carried) {
      byId.putIfAbsent(guest.id, () => guest);
    }
    final link = this.link;
    final guest = link?.guest;
    final guestMe = guest?._me;
    if (link != null && link._guestIn && guest != null && guestMe != null) {
      byId[guest.myId] = guestMe;
    }
    final members = byId.values.toList();
    onRosterChanged?.call(members);
    if (link != null && link._guestIn) {
      guest?.onRosterChanged?.call(members);
    }
  }

  /// What this player's presence says: with a second player on this device
  /// it carries theirs, so people on other devices count them as well and
  /// a room of two is full for everybody.
  Map<String, dynamic> _tracked(LobbyPresence me) {
    final json = me.toJson();
    final link = this.link;
    final guestMe = link?.guest._me;
    if (link != null &&
        link._guestIn &&
        identical(link.host, this) &&
        guestMe != null) {
      json['local'] = guestMe.toJson();
    }
    return json;
  }

  void _retrack() {
    final me = _me;
    if (me != null) {
      _presence?.track(_tracked(me));
    }
  }

  /// Joins up with the other player on this device, see [LocalLink].
  LocalLink? link;

  /// Whether [id] is the other player on this device, who costs the room
  /// nothing.
  bool isLocalPeer(String id) {
    final link = this.link;
    return link != null && link._guestIn && link.peerOf(this)?.myId == id;
  }

  Future<void> _teardownChannel() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _presence?.close();
    _presence = null;
    othersPresent = false;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }

  /// Tells everybody in the room that it is closed, then leaves it.
  Future<void> closeRoom() async {
    final link = this.link;
    if (link != null && link._guestIn) {
      link.peerOf(this)?._deliver(NetEvent.close, {'id': myId});
    }
    final channel = _channel;
    if (channel != null) {
      try {
        await channel.sendBroadcastMessage(
          event: NetEvent.close.name,
          payload: {'id': myId},
        );
      } on Object {
        // Leaving matters more than the goodbye.
      }
    }
    await dispose();
  }

  Future<void> dispose() async {
    _disposed = true;
    _joinedAt = null;
    final link = this.link;
    if (link != null && identical(link.guest, this) && link._guestIn) {
      link._guestIn = false;
      link.host.onPeerLeft?.call(myId);
      link.host._retrack();
      link.host._emitRoster();
    }
    await _teardownChannel();
  }
}

/// The two games of two players on one device, joined without the server:
/// what one sends the other hears at once, and the second player shows in
/// the room's roster through the first. Nothing of it goes over Realtime,
/// and the room takes no slot for it. People on other devices do not see
/// the second player this way; with any of them in the room the second
/// player joins over a connection of their own instead.
class LocalLink {
  LocalLink(this.host, this.guest) {
    host.link = this;
    guest.link = this;
  }

  /// The first player's game, which holds the room's channel.
  final NetService host;

  /// The second player's game, which has no channel.
  final NetService guest;

  bool _guestIn = false;

  NetService? peerOf(NetService of) => identical(of, host)
      ? guest
      : identical(of, guest)
      ? host
      : null;
}
