import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../db/room_registry.dart';
import 'inbound_limiter.dart';
import 'net_events.dart';
import 'payloads/death_payload.dart';
import 'payloads/flag_payload.dart';
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
import 'retry_backoff.dart';
import 'room_key.dart';

class NetService {
  NetService({
    required this.myId,
    required this.room,
    this.isHost = true,
    this.offline = false,
    SupabaseClient? client,
    this.key,
    this.registry,
  }) : assert(key == null || key.id == myId, 'the id follows the key'),
       _ownClient = client;

  /// The key this game speaks with, whose hash is [myId]. Every message
  /// then carries a tag for each player in the room who has a key too, and
  /// a message in the name of such a player only counts with a tag from
  /// them. Without a key (tests, the watch) messages go out bare and come
  /// in as they are, as before keys.
  final RoomKey? key;

  /// Where the key enters the room and the server's order of the room's
  /// keys comes from, see [order].
  final RoomRegistry? registry;

  /// Plays without a room channel: the Apple Watch, which watchOS gives no
  /// WebSocket for. Rooms there never connected and retried every 30 s, so
  /// the watch plays every mode alone against CPU tanks.
  final bool offline;

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
  void Function(FlagPayload payload)? onFlag;
  void Function(GrenadePayload payload)? onGrenade;
  void Function(DronePayload payload)? onDrone;
  void Function(BlastPayload payload)? onBlast;
  void Function(AirPayload payload)? onAir;
  void Function(SquadPayload payload)? onSquad;
  void Function(SquadOrderPayload payload)? onSquadOrder;
  void Function(UsePayload payload)? onUse;
  void Function(RoundStartPayload payload)? onRoundStart;
  void Function(List<LobbyPresence> roster)? onRosterChanged;
  void Function(String id)? onPeerLeft;

  /// Ids that more than one presence in the room claims: somebody poses
  /// as another player. Ids with a key never count: a copy of their
  /// presence cannot speak for them.
  Set<String> duplicateIds = const {};

  /// Who came into the room when and who owns it, by the server, once it
  /// answered. Null before, offline and without a key.
  RoomOrder? order;

  /// Whether a message that came in counts, asked of the game after the
  /// tags were checked: [claimed] is the id the message speaks for
  /// (`from`, else `id`), [sender] the player whose tag proved it was
  /// them, null for a message without a valid tag. Only asked with a key.
  bool Function(NetEvent event, String? claimed, String? sender)? admits;

  /// Public keys of players with a key, by id, also of those who left: a
  /// late message in their name still needs their tag.
  final _peerKeys = <String, Uint8List>{};
  final _secrets = <String, Uint8List?>{};
  final _lastCounter = <String, int>{};

  /// Players on other devices with a key in the room now: every message
  /// carries a tag for each of them.
  Set<String> _keyed = const {};

  /// Running number of the messages this game sends, so a tag copied from
  /// an older message does not count again. It starts from the clock, as
  /// a game that left and came back keeps its key.
  late int _counter = clock.now().millisecondsSinceEpoch;

  /// How often the order was asked for an id the server did not know yet:
  /// a player's presence can come before their key reached the server.
  final _orderAsks = <String, int>{};
  Timer? _orderTimer;

  /// Whether [id] speaks with a key: messages in its name need its tag.
  bool isVerified(String id) =>
      id == myId ? key != null : _peerKeys.containsKey(id);

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

  /// Whether this player is alone in the room, see [othersPresent].
  bool get alone => !othersPresent;
  bool _disposed = false;

  /// Whether the room's channel is joined right now.
  bool _up = false;

  /// When the room's channel last dropped, null while it never did.
  DateTime? _droppedAt;

  /// Whether this game may not know who is in the room: its channel is
  /// down, or dropped less than [window] ago. Others who dropped with it
  /// come back on their own backoff, and were never gone.
  bool blindFor(Duration window) {
    final dropped = _droppedAt;
    return dropped != null &&
        (!_up || clock.now().difference(dropped) < window);
  }

  /// Tests: the channel dropped just now and is down.
  @visibleForTesting
  void dropForTest() {
    _up = false;
    _droppedAt = clock.now();
  }

  /// Tests: the channel is joined again.
  @visibleForTesting
  void upForTest() => _up = true;

  final _backoff = RetryBackoff();
  Timer? _reconnect;
  final _subscriptions = <StreamSubscription<void>>[];

  SupabaseClient get _client => _ownClient ?? Supabase.instance.client;

  Future<void> connect(LobbyPresence me) async {
    _disposed = false;
    _me = me;
    if (offline) {
      _registerHandlers(null);
      // Alone in the room, and so its host.
      scheduleMicrotask(() => onRosterChanged?.call([me]));
      return;
    }
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
    _enterRoom(0);
    final topic = 'game-arena-$room';
    final channel = _client.channel(
      topic,
      options: const RealtimeChannelConfig(self: false),
    );
    _channel = channel;
    _presence = PresenceThrottle(channel, topic);
    _registerHandlers(channel);
    _subscriptions.add(channel.onPresenceSync.listen((_) => _emitRoster()));
    _subscriptions.add(
      channel.onPresenceJoin.listen((join) {
        // A key the server did not know when it was last asked may be in
        // by now (an entry that failed at first): ask again.
        for (final presence in join.newPresences) {
          if (presence.payload['id'] case final String id
              when order?[id] == null) {
            _orderAsks.remove(id);
          }
        }
        _emitRoster();
      }),
    );
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
          _up = true;
          _backoff.up();
          final me = _me;
          if (me != null) {
            _presence?.track(_tracked(me));
          }
        } else if (change.status == RealtimeSubscribeStatus.channelError ||
            change.status == RealtimeSubscribeStatus.closed) {
          _scheduleReconnect(change.error ?? change.status.name);
        }
      }),
    );
    channel.subscribe();
  }

  /// Tests: hears messages handed in with [deliverForTest] instead of a
  /// channel, so two games can play each other without a server.
  @visibleForTesting
  void listenWithoutChannel() => _registerHandlers(null);

  /// Tests: one message that came in, as from the channel.
  @visibleForTesting
  void deliverForTest(NetEvent event, Map<String, dynamic> json) {
    if (_admit(event, json)) {
      _deliver(event, json);
    }
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
    _listen(channel, NetEvent.squadOrder, (json) {
      if (SquadOrderPayload.tryParse(json) case final payload?) {
        onSquadOrder?.call(payload);
      }
    });
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
    _listen(channel, NetEvent.flag, (json) {
      final payload = FlagPayload.tryParse(json);
      if (payload != null) {
        onFlag?.call(payload);
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
  final _limiter = InboundLimiter();

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
        if (!_admit(event, json)) {
          return;
        }
        _deliver(event, json);
        // The second player on this device hears what came in as well.
        final link = this.link;
        if (link != null && link._guestIn && identical(link.host, this)) {
          link.guest._deliver(event, json);
        }
      }),
    );
  }

  /// Whether a message from the channel counts: one in the name of a
  /// player with a key needs that player's tag, and the game decides on
  /// the rest ([admits]).
  bool _admit(NetEvent event, Map<String, dynamic> json) {
    if (key == null) {
      return true;
    }
    final claimed = json['from'] ?? json['id'];
    final claimedId = claimed is String ? claimed : null;
    final sender = _senderOf(event, json);
    // Nobody speaks for a player with a key but that player.
    if (claimedId != null && isVerified(claimedId) && claimedId != sender) {
      return false;
    }
    return admits?.call(event, claimedId, sender) ?? true;
  }

  /// The player whose tag for this game proves they sent [json], or null.
  String? _senderOf(NetEvent event, Map<String, dynamic> json) {
    final mac = json[RoomMac.field];
    if (mac is! Map) {
      return null;
    }
    final sender = mac['s'];
    final counter = mac['n'];
    final tags = mac['t'];
    if (sender is! String || counter is! int || tags is! Map) {
      return null;
    }
    final tag = tags[myId];
    final secret = _secretOf(sender);
    if (tag is! String || secret == null) {
      return null;
    }
    if (RoomMac.tag(secret, event.name, json, sender, counter) != tag ||
        counter <= (_lastCounter[sender] ?? 0)) {
      return null;
    }
    _lastCounter[sender] = counter;
    return sender;
  }

  Uint8List? _secretOf(String id) {
    final key = this.key;
    final public = _peerKeys[id];
    if (key == null || public == null) {
      return null;
    }
    return _secrets.putIfAbsent(id, () => key.sharedWith(public, room));
  }

  /// [payload] with a tag for everybody in the room who has a key.
  Map<String, dynamic> _seal(NetEvent event, Map<String, dynamic> payload) {
    if (key == null || _keyed.isEmpty) {
      return payload;
    }
    final counter = ++_counter;
    final tags = <String, String>{
      for (final id in _keyed)
        if (_secretOf(id) case final secret?)
          id: RoomMac.tag(secret, event.name, payload, myId, counter),
    };
    return {
      ...payload,
      RoomMac.field: {'s': myId, 'n': counter, 't': tags},
    };
  }

  /// Enters this game's key into the room's order on the server, not
  /// waited for: the room opens without the server as well. A failed
  /// entry is tried again a few times. Until it is in, this game ranks
  /// after every key the server knows on the other screens, so an owner
  /// whose entry failed lost the room to a guest, while hosting it on its
  /// own screen: two hosts.
  void _enterRoom(int attempt) {
    final key = this.key;
    final registry = this.registry;
    _enterTimer?.cancel();
    _enterTimer = null;
    if (key == null || registry == null || _disposed) {
      return;
    }
    fireAndForget(
      registry.enter(room, key.encoded, owner: isHost).then((entered) {
        if (_disposed) {
          return;
        }
        if (!entered) {
          if (attempt < _enterGaps.length) {
            _enterTimer = Timer(
              _enterGaps[attempt],
              () => _enterRoom(attempt + 1),
            );
          }
          return;
        }
        _orderAsks.remove(myId);
        _askOrder();
        if (attempt > 0) {
          // The others may have given up asking for this key: a presence
          // that comes in again makes them ask once more.
          _retrack();
        }
      }),
      'Entering the room',
    );
  }

  Timer? _enterTimer;

  /// Tests: enters the key as [connect] does, without a channel.
  @visibleForTesting
  void enterForTest() => _enterRoom(0);

  /// Waits before each further try to enter the room.
  static const _enterGaps = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ];

  /// Asks the server for the room's order when somebody with a key is in
  /// the room that it did not know yet, a few times with growing gaps.
  void _askOrder() {
    final registry = this.registry;
    if (key == null || registry == null || _orderTimer != null || _disposed) {
      return;
    }
    final known = order?.pilots ?? const {};
    final missing = [
      for (final id in {myId, ..._keyed})
        if (!known.containsKey(id) && (_orderAsks[id] ?? 0) < _orderGaps.length)
          id,
    ];
    if (missing.isEmpty) {
      return;
    }
    var attempt = 0;
    for (final id in missing) {
      attempt = max(attempt, _orderAsks[id] ?? 0);
      _orderAsks[id] = (_orderAsks[id] ?? 0) + 1;
    }
    _orderTimer = Timer(_orderGaps[attempt], () async {
      final next = await registry.order(room);
      _orderTimer = null;
      if (_disposed) {
        return;
      }
      if (next != null) {
        order = next;
        _emitRoster();
      }
      _askOrder();
    });
  }

  /// Waits before each ask for the order: the first soon, the later ones
  /// for a key that reaches the server late.
  static const _orderGaps = [
    Duration(milliseconds: 300),
    Duration(seconds: 3),
    Duration(seconds: 10),
  ];

  /// One message that came in.
  void _deliver(NetEvent event, Map<String, dynamic> json) {
    final roundStart = event == NetEvent.roundStart;
    // A message about this player sent by somebody else (the host telling
    // a builder what is left of their gun) names its sender in `from`.
    final from = json['from'] ?? json['id'];
    // Round starts come through a replay as well, and are not part of it.
    if (from == myId || (muted && !roundStart)) {
      return;
    }
    final handler = _handlers[event];
    if (handler == null) {
      return;
    }
    if (!_limiter.admit(event, from is String ? from : null)) {
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

  /// [why] goes into the log: on the watch the channel kept dropping and
  /// the log did not say why.
  void _scheduleReconnect([Object? why]) {
    // An error is often followed by a close: one attempt for both.
    if (_disposed || _reconnect != null) {
      return;
    }
    final me = _me;
    if (me == null) {
      return;
    }
    _up = false;
    _droppedAt = clock.now();
    final wait = _backoff.next();
    debugPrint(
      'Room channel $room dropped, rejoining in ${wait.inSeconds} s '
      '(attempt ${_backoff.failures}${why == null ? '' : ': $why'})',
    );
    _reconnect = Timer(wait, () async {
      _reconnect = null;
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
    transmit(event, _seal(event, payload));
  }

  /// Puts one message on the channel.
  @protected
  void transmit(NetEvent event, Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) {
      return;
    }
    fireAndForget(
      channel.sendBroadcastMessage(event: event.name, payload: payload),
      'Sending ${event.name}',
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
    _rosterFrom([
      for (final state in channel.presenceState())
        for (final presence in state.presences) presence.payload,
    ]);
  }

  /// Tests: the room's presences, as the channel would sync them.
  @visibleForTesting
  void syncPresencesForTest(List<Map<String, dynamic>> presences) =>
      _rosterFrom(presences);

  void _rosterFrom(List<Map<String, dynamic>> presences) {
    // Keys first: a presence without the key of an id that has one, or
    // with a key that is not the id's, is somebody posing as that player.
    final keyed = <String>{};
    for (final payload in presences) {
      final local = payload['local'];
      for (final json in [payload, if (local is Map<String, dynamic>) local]) {
        final id = json['id'];
        final public = RoomKey.decode(json['key']);
        if (id is String && public != null && RoomKey.idOf(public) == id) {
          keyed.add(id);
          _peerKeys.putIfAbsent(id, () => public);
        }
      }
    }
    bool genuine(Map<String, dynamic> json, String id) => json['key'] == null
        ? !_peerKeys.containsKey(id)
        : RoomKey.belongsTo(id, json['key']);
    final byId = <String, LobbyPresence>{};
    final seen = <String>{};
    final twice = <String>{};
    final carried = <LobbyPresence>[];
    for (final payload in presences) {
      final member = LobbyPresence.tryParse(payload);
      if (member == null || !genuine(payload, member.id)) {
        continue;
      }
      if (!seen.add(member.id) && !keyed.contains(member.id)) {
        twice.add(member.id);
      }
      byId[member.id] = member;
      // A second player on that device, who has no presence of their own.
      final local = payload['local'];
      if (local is Map<String, dynamic>) {
        final guest = LobbyPresence.tryParse(local);
        if (guest != null && genuine(local, guest.id)) {
          carried.add(guest);
        }
      }
    }
    duplicateIds = twice;
    _keyed = {
      for (final id in keyed)
        if (id != myId && !isLocalPeer(id)) id,
    };
    _askOrder();
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
  /// Tests: what this game's presence says for [me].
  @visibleForTesting
  Map<String, dynamic> trackedForTest(LobbyPresence me) => _tracked(me);

  Map<String, dynamic> _tracked(LobbyPresence me) {
    final json = me.toJson();
    if (key case final key?) {
      json['key'] = key.encoded;
    }
    final link = this.link;
    final guest = link?.guest;
    final guestMe = guest?._me;
    if (link != null &&
        link._guestIn &&
        identical(link.host, this) &&
        guestMe != null) {
      json['local'] = {
        ...guestMe.toJson(),
        if (guest?.key case final guestKey?) 'key': guestKey.encoded,
      };
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
          payload: _seal(NetEvent.close, {'id': myId}),
        );
      } on Object {
        // Leaving matters more than the goodbye.
      }
    }
    await dispose();
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnect?.cancel();
    _reconnect = null;
    _orderTimer?.cancel();
    _orderTimer = null;
    _enterTimer?.cancel();
    _enterTimer = null;
    _orderAsks.clear();
    order = null;
    _backoff.reset();
    _up = false;
    _droppedAt = null;
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
