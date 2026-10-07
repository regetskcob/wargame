import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'net_events.dart';
import 'payloads/death_payload.dart';
import 'payloads/defense_payload.dart';
import 'payloads/hit_payload.dart';
import 'payloads/lobby_presence.dart';
import 'payloads/obstacle_payload.dart';
import 'payloads/soldier_payload.dart';
import 'payloads/power_up_payload.dart';
import 'payloads/round_start_payload.dart';
import 'payloads/ship_state_payload.dart';
import 'payloads/shoot_payload.dart';

class NetService {
  NetService({required this.myId, required this.room, this.isHost = true});

  final String myId;

  /// Code of the room whose channel this connects to.
  final String room;

  /// Whether this player opened the room. Others only join and play.
  final bool isHost;

  void Function(ShipStatePayload payload)? onShipState;
  void Function(ShootPayload payload)? onShoot;
  void Function(HitPayload payload)? onHit;
  void Function(DeathPayload payload)? onDeath;
  void Function(PickupPayload payload)? onPickup;
  void Function(SmokePayload payload)? onSmoke;
  void Function(ObstaclePayload payload)? onObstacle;
  void Function(SoldierPayload payload)? onSoldier;
  void Function(DefensePayload payload)? onDefense;
  void Function(TowerPayload payload)? onTower;
  void Function(RoundStartPayload payload)? onRoundStart;
  void Function(List<LobbyPresence> roster)? onRosterChanged;
  void Function(String id)? onPeerLeft;

  RealtimeChannel? _channel;
  LobbyPresence? _me;
  bool _disposed = false;
  final _subscriptions = <StreamSubscription<void>>[];

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> connect(LobbyPresence me) async {
    _me = me;
    final channel = _client.channel(
      'game-arena-$room',
      options: const RealtimeChannelConfig(self: false),
    );
    _channel = channel;
    _listen(
      channel.onBroadcast(event: NetEvent.state.name),
      (json) => onShipState?.call(ShipStatePayload.fromJson(json)),
    );
    _listen(
      channel.onBroadcast(event: NetEvent.shoot.name),
      (json) => onShoot?.call(ShootPayload.fromJson(json)),
    );
    _listen(
      channel.onBroadcast(event: NetEvent.hit.name),
      (json) => onHit?.call(HitPayload.fromJson(json)),
    );
    _listen(
      channel.onBroadcast(event: NetEvent.death.name),
      (json) => onDeath?.call(DeathPayload.fromJson(json)),
    );
    _listen(
      channel.onBroadcast(event: NetEvent.soldier.name),
      (json) => onSoldier?.call(SoldierPayload.fromJson(json)),
    );
    _listen(
      channel.onBroadcast(event: NetEvent.obstacle.name),
      (json) => onObstacle?.call(ObstaclePayload.fromJson(json)),
    );
    _listen(
      channel.onBroadcast(event: NetEvent.pickup.name),
      (json) => onPickup?.call(PickupPayload.fromJson(json)),
    );
    _listen(
      channel.onBroadcast(event: NetEvent.smoke.name),
      (json) => onSmoke?.call(SmokePayload.fromJson(json)),
    );
    _listen(
      channel.onBroadcast(event: NetEvent.defense.name),
      (json) => onDefense?.call(DefensePayload.fromJson(json)),
    );
    _listen(
      channel.onBroadcast(event: NetEvent.tower.name),
      (json) => onTower?.call(TowerPayload.fromJson(json)),
    );
    _subscriptions.add(
      channel
          .onBroadcast(event: NetEvent.roundStart.name)
          .listen(
            (json) => onRoundStart?.call(RoundStartPayload.fromJson(json)),
          ),
    );
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
      channel.onStatusChange.listen((change) async {
        if (change.status == RealtimeSubscribeStatus.subscribed) {
          final me = _me;
          if (me != null) {
            await channel.track(me.toJson());
          }
        } else if (change.status == RealtimeSubscribeStatus.channelError ||
            change.status == RealtimeSubscribeStatus.closed) {
          _scheduleReconnect();
        }
      }),
    );
    channel.subscribe();
  }

  void _listen(
    Stream<Map<String, dynamic>> stream,
    void Function(Map<String, dynamic> json) handler,
  ) {
    _subscriptions.add(
      stream.listen((json) {
        if (json['id'] == myId) {
          return;
        }
        handler(json);
      }),
    );
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
    await _channel?.track(me.toJson());
  }

  void _emitRoster() {
    final channel = _channel;
    if (channel == null) {
      return;
    }
    final byId = <String, LobbyPresence>{};
    for (final state in channel.presenceState()) {
      for (final presence in state.presences) {
        final json = presence.payload;
        if (json['id'] is String &&
            json['name'] is String &&
            json['color'] is int &&
            json['phase'] is String) {
          final member = LobbyPresence.fromJson(json);
          byId[member.id] = member;
        }
      }
    }
    onRosterChanged?.call(byId.values.toList());
  }

  Future<void> _teardownChannel() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _teardownChannel();
  }
}
