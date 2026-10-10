import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../db/account_service.dart';
import '../db/profile_service.dart';
import '../db/score_service.dart';
import '../db/supabase_schema.g.dart';
import '../game/game_phase.dart';
import '../game/tank_game.dart';
import '../l10n/l10n.dart';
import '../app/env.dart';
import '../net/net_service.dart';
import '../net/room_directory.dart';
import 'tv_input.dart';
import '../net/pad_link.dart';
import 'seats.dart';

/// A second player on the same Apple TV.
///
/// With two controllers in (or phones, or the Siri Remote as the second),
/// the second player gets a game of their own that joins the room of the
/// first, as a pilot from another device would. Rounds then show on a split
/// screen, each half from its own tank, and everything the game knows of
/// two pilots in a room works as it does online. The first player runs the
/// menus, the second rides along.
class SecondPlayer extends ChangeNotifier {
  SecondPlayer(this._host);

  /// The first player's game, which changes with every room.
  final TankGame Function() _host;

  /// The second player's game, null while only one plays.
  TankGame? guest;

  var _seats = const <DuelSeat>[];

  /// What steers each player, the first player's seat first.
  List<DuelSeat> get seats => _seats;
  bool _attached = false;

  /// Starts watching the controllers and phones.
  void attach() {
    if (_attached) {
      return;
    }
    _attached = true;
    TvInputSeats.listenable.addListener(update);
    update();
  }

  @override
  void dispose() {
    TvInputSeats.listenable.removeListener(update);
    _drop();
    super.dispose();
  }

  /// Set while [update] runs. Handing a phone to the second game changes
  /// its presence, which on this device reaches the first game's roster at
  /// once, and the roster calls [update] again: with two phones on an iPad
  /// that ran in circles until the stack overflowed, claiming the phones'
  /// slot with every turn.
  var _updating = false;

  /// What [_hand] gave out last, so the same seats are not handed again.
  List<DuelSeat>? _handed;
  TankGame? _handedHost;
  TankGame? _handedGuest;

  /// Brings the second game in or out as players come and go, and hands
  /// each player their controller. Only between rounds: a round in play
  /// keeps who it has.
  void update() {
    if (_updating) {
      return;
    }
    _updating = true;
    try {
      _update();
    } finally {
      _updating = false;
    }
  }

  void _update() {
    final host = _host();
    final between =
        host.phase.value == GamePhase.lobby ||
        host.phase.value == GamePhase.closed;
    final seats = duelSeats();
    // Two halves need a big screen: the television, a computer or a tablet.
    final two = seats.length >= 2 && splitScreenFits();
    if (!between && guest != null) {
      return;
    }
    if (!two) {
      _drop();
      // One player: a controller of their own steers their tank, as a
      // paired phone does.
      final pads = TvInput.instance.pads;
      host
        ..localGuest = false
        ..tvPlayer = onTv
            ? 0
            : pads.indexWhere((pad) => pad.kind == TvPadKind.gamepad);
      return;
    }
    _seats = seats.take(2).toList();
    // Alone in the room the two games talk on this device; with people on
    // other devices the second player needs a connection of their own, or
    // those would not see them.
    final current = guest;
    final local = !host.roster.value.any(
      (member) => member.id != host.myId && member.id != current?.myId,
    );
    if (current == null ||
        current.net.room != host.net.room ||
        _local != local) {
      _drop();
      _local = local;
      guest = _join(host, local: local);
      host.partner = guest;
      notifyListeners();
    }
    host.localGuest = true;
    _hand(host, guest!);
  }

  /// The room changed, as after a new one was opened: follow it.
  void followRoom() => update();

  /// The second game's own connection, when it needs one: one connection
  /// joins a room's channel only once, and both games sit in the same room.
  SupabaseClient? _connection;

  /// Whether the second game talks to the first on this device only.
  bool? _local;

  TankGame _join(TankGame host, {required bool local}) {
    final client = Supabase.instance.client;
    final random = Random();
    final id = [
      for (var i = 0; i < 16; i++) random.nextInt(16).toRadixString(16),
    ].join();
    final NetService net;
    final RoomDirectory directory;
    if (local) {
      // On this device only: costs no messages and takes no room slot.
      net = NetService(myId: id, room: host.net.room, isHost: false);
      LocalLink(host.net, net);
      directory = _NoDirectory(room: host.net.room);
    } else {
      // Only for the room's channel: no sign-in, nothing kept.
      final connection = SupabaseClient(
        Env.supabaseUrl,
        Env.supabaseKey,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
      );
      _connection = connection;
      net = NetService(
        myId: id,
        room: host.net.room,
        isHost: false,
        client: connection,
      );
      directory = RoomDirectory(room: host.net.room, client: connection);
    }
    return TankGame(
        net: net,
        directory: directory,
        myId: id,
        scoreService: UnrankedScores(client),
        profiles: _NoProfile(client),
        accounts: AccountService(client),
      )
      ..myName = tr('SPIELER 2', 'PLAYER 2')
      ..sharesScreen = true
      // Steered by a controller or a phone, never by touch.
      ..touchMode.value = false;
  }

  /// Each seat steers its game: a controller by its number, a phone by the
  /// route the pairing gives it.
  void _hand(TankGame host, TankGame guest) {
    if (listEquals(_handed, _seats) &&
        identical(_handedHost, host) &&
        identical(_handedGuest, guest)) {
      return;
    }
    _handed = _seats;
    _handedHost = host;
    _handedGuest = guest;
    PadScreen.instance.clearRoutes();
    for (final (seat, game) in [(_seats[0], host), (_seats[1], guest)]) {
      game.tvPlayer = seat.pad;
      final phone = seat.phone;
      if (phone != null) {
        PadScreen.instance.route(phone, game);
      }
    }
  }

  void _drop() {
    final current = guest;
    if (current == null) {
      return;
    }
    guest = null;
    _local = null;
    _handed = null;
    _host().partner = null;
    PadScreen.instance.clearRoutes();
    final connection = _connection;
    _connection = null;
    unawaited(current.leave().whenComplete(() async => connection?.dispose()));
    notifyListeners();
  }
}

/// What a second player on the Apple TV counts for: nothing, two players
/// share one account there.
class UnrankedScores extends ScoreService {
  UnrankedScores(super.client);

  @override
  bool get isGuest => true;
}

/// The room list is the first player's business: the second game on this
/// device joins no list channel.
class _NoDirectory extends RoomDirectory {
  _NoDirectory({required super.room});

  @override
  void connect() {}

  @override
  Future<void> advertise(RoomListing? listing) async {}

  @override
  Future<void> dispose() async {}
}

/// The second player keeps no profile: the account's call sign and look
/// belong to the first.
class _NoProfile extends ProfileService {
  _NoProfile(super.client);

  @override
  Future<PlayersRow?> load() async => null;

  @override
  Future<void> save({required String name, required int style}) async {}
}
