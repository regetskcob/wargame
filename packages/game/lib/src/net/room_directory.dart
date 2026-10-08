import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A room that shows up in the public list.
class RoomListing {
  const RoomListing({
    required this.room,
    required this.host,
    required this.players,
    required this.inMatch,
    this.teams = false,
  });

  factory RoomListing.fromJson(Map<String, dynamic> json) => RoomListing(
    room: json['room'] as String,
    host: switch (json['host'] as String? ?? '') {
      final name when name.length > 16 => name.substring(0, 16),
      final name => name,
    },
    players: json['players'] as int? ?? 1,
    inMatch: json['inMatch'] as bool? ?? false,
    teams: json['teams'] as bool? ?? false,
  );

  final String room;

  /// Name of the player who opened it.
  final String host;
  final int players;
  final bool inMatch;
  final bool teams;

  Map<String, dynamic> toJson() => {
    'room': room,
    'host': host,
    'players': players,
    'inMatch': inMatch,
    'teams': teams,
  };

  @override
  bool operator ==(Object other) =>
      other is RoomListing &&
      other.room == room &&
      other.host == host &&
      other.players == players &&
      other.inMatch == inMatch &&
      other.teams == teams;

  @override
  int get hashCode => Object.hash(room, host, players, inMatch, teams);
}

/// The public list of rooms, kept in Presence on a channel of its own. Hosts
/// of public rooms put their room on it, everybody can read it. A room
/// vanishes from the list by itself when its host closes the window.
class RoomDirectory {
  RoomDirectory({required this.room});

  /// Own room, left out of [rooms].
  final String room;

  final rooms = ValueNotifier<List<RoomListing>>(const []);

  RealtimeChannel? _channel;
  RoomListing? _listing;
  var _subscribed = false;
  final _subscriptions = <StreamSubscription<void>>[];

  SupabaseClient get _client => Supabase.instance.client;

  void connect() {
    final channel = _client.channel(
      'game-rooms',
      options: const RealtimeChannelConfig(self: true),
    );
    _channel = channel;
    _subscriptions
      ..add(channel.onPresenceSync.listen((_) => _emit()))
      ..add(channel.onPresenceJoin.listen((_) => _emit()))
      ..add(channel.onPresenceLeave.listen((_) => _emit()))
      ..add(
        channel.onStatusChange.listen((change) async {
          _subscribed = change.status == RealtimeSubscribeStatus.subscribed;
          if (_subscribed && _listing != null) {
            await channel.track(_listing!.toJson());
          }
        }),
      );
    channel.subscribe();
  }

  /// Lists the own room, or takes it off the list with null.
  Future<void> advertise(RoomListing? listing) async {
    if (listing == _listing) {
      return;
    }
    _listing = listing;
    final channel = _channel;
    if (channel == null || !_subscribed) {
      return;
    }
    if (listing == null) {
      await channel.untrack();
    } else {
      await channel.track(listing.toJson());
    }
  }

  void _emit() {
    final channel = _channel;
    if (channel == null) {
      return;
    }
    final byRoom = <String, RoomListing>{};
    for (final state in channel.presenceState()) {
      for (final presence in state.presences) {
        final json = presence.payload;
        if (json['room'] is! String || json['room'] == room) {
          continue;
        }
        // One bad entry must not empty the list for everybody.
        try {
          final listing = RoomListing.fromJson(json);
          byRoom[listing.room] = listing;
        } on Object {
          continue;
        }
      }
    }
    rooms.value = byRoom.values.toList()
      ..sort((a, b) {
        // Rooms that wait for players first, then the fuller ones.
        if (a.inMatch != b.inMatch) {
          return a.inMatch ? 1 : -1;
        }
        return b.players.compareTo(a.players);
      });
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }
}
