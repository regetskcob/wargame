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
import '../net/pad_link.dart';
import 'duel_view.dart';

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

  /// Brings the second game in or out as players come and go, and hands
  /// each player their controller. Only between rounds: a round in play
  /// keeps who it has.
  void update() {
    final host = _host();
    final between =
        host.phase.value == GamePhase.lobby ||
        host.phase.value == GamePhase.closed;
    final seats = duelSeats();
    final two = seats.length >= 2 && !DuelView.running;
    if (!between && guest != null) {
      return;
    }
    if (!two) {
      _drop();
      host
        ..localGuest = false
        ..tvPlayer = 0;
      return;
    }
    _seats = seats.take(2).toList();
    final current = guest;
    if (current == null || current.net.room != host.net.room) {
      _drop();
      guest = _join(host);
      notifyListeners();
    }
    host.localGuest = true;
    _hand(host, guest!);
  }

  /// The room changed, as after a new one was opened: follow it.
  void followRoom() => update();

  /// The second game's own connection: one connection joins a room's
  /// channel only once, and both games sit in the same room.
  SupabaseClient? _connection;

  TankGame _join(TankGame host) {
    final client = Supabase.instance.client;
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
    final random = Random();
    final id = [
      for (var i = 0; i < 16; i++) random.nextInt(16).toRadixString(16),
    ].join();
    return TankGame(
      net: NetService(
        myId: id,
        room: host.net.room,
        isHost: false,
        client: connection,
      ),
      directory: RoomDirectory(room: host.net.room, client: connection),
      myId: id,
      scoreService: UnrankedScores(client),
      profiles: _NoProfile(client),
      accounts: AccountService(client),
    )..myName = tr('SPIELER 2', 'PLAYER 2');
  }

  /// Each seat steers its game: a controller by its number, a phone by the
  /// route the pairing gives it.
  void _hand(TankGame host, TankGame guest) {
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

/// The second player keeps no profile: the account's call sign and look
/// belong to the first.
class _NoProfile extends ProfileService {
  _NoProfile(super.client);

  @override
  Future<PlayersRow?> load() async => null;

  @override
  Future<void> save({required String name, required int style}) async {}
}
