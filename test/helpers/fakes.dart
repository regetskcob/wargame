import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:wargame/src/app/overlay_ids.dart';
import 'package:wargame/src/db/account_service.dart';
import 'package:wargame/src/db/profile_service.dart';
import 'package:wargame/src/db/room_slots.dart';
import 'package:wargame/src/db/score_service.dart';
import 'package:wargame/src/db/supabase_schema.g.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/l10n/l10n.dart';
import 'package:wargame/src/net/net_service.dart';
import 'package:wargame/src/net/payloads/lobby_presence.dart';
import 'package:wargame/src/net/room_directory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User _user({required bool guest}) => User(
  id: guest ? 'guest' : 'account',
  audience: 'authenticated',
  createdAt: DateTime.utc(2026, 10, 8),
  email: guest ? null : 'peter@example.com',
  isAnonymous: guest,
);

/// Stands in for Supabase: signed into an account, signing out leaves a
/// fresh guest behind, or fails when told to.
class FakeAccounts implements AccountService {
  FakeAccounts({this.fails = false});

  final bool fails;
  var signOuts = 0;

  @override
  final user = ValueNotifier<User?>(_user(guest: false));

  @override
  final providers = ValueNotifier<List<(OAuthProvider, String)>>(const []);

  @override
  Future<void> loadProviders() async {}

  @override
  bool get isGuest => user.value?.isAnonymous ?? true;

  @override
  String? get email => user.value?.email;

  @override
  AppLang? language;

  @override
  Future<void> rememberLanguage(AppLang lang) async => language = lang;

  @override
  bool get olderThanTutorial => false;

  @override
  bool tutorialSeen({required bool touch}) => true;

  @override
  Future<void> rememberTutorialSeen({required bool touch}) async {}

  @override
  Future<void> signOut() async {
    signOuts++;
    if (fails) {
      throw Exception('offline');
    }
    user.value = _user(guest: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Keeps nothing, there is no database in the tests.
class FakeProfiles implements ProfileService {
  final saved = <String>[];

  @override
  Future<void> save({required String name, required int style}) async {
    saved.add(name);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeScores implements ScoreService {
  @override
  String? get myId => null;

  @override
  Future<List<ScoresRow>> topScores({int limit = 20}) async => const [];

  @override
  Future<List<WeeklyScoresRow>> weeklyScores({int limit = 20}) async =>
      const [];

  @override
  Future<List<TankScoresRow>> myTankScores() async => const [];

  @override
  Future<ScoresRow?> myScore() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Never reaches a server, only counts joining and leaving the room.
class FakeNet extends NetService {
  FakeNet({super.isHost}) : super(myId: 'me', room: 'TEST1');

  var connects = 0;
  var disposes = 0;

  @override
  Future<void> connect(LobbyPresence me) async => connects++;

  @override
  Future<void> dispose() async => disposes++;
}

/// The Realtime budget without a server: every claim gets in unless told
/// otherwise, and counting changes nothing.
class FakeSlots implements RoomSlots {
  FakeSlots({this.free = true});

  bool free;

  /// Every claim: its key and load.
  final claimed = <(String, int)>[];

  List<String> get claims => [for (final c in claimed) c.$1];

  @override
  Future<bool> claim(String key, int messages) async {
    claimed.add((key, messages));
    return free;
  }

  @override
  Future<void> count() async {}
}

/// The public room list without a server behind it.
class FakeDirectory extends RoomDirectory {
  FakeDirectory() : super(room: 'TEST1');

  final listings = <RoomListing?>[];

  @override
  void connect() {}

  @override
  Future<void> advertise(RoomListing? listing) async => listings.add(listing);

  @override
  Future<void> dispose() async {}
}

/// A game that never connects: enough for the pages around it.
TankGame offlineGame({
  AccountService? accounts,
  ProfileService? profiles,
  NetService? net,
  RoomSlots? slots,
}) => TankGame(
  net: net ?? FakeNet(),
  myId: 'me',
  scoreService: FakeScores(),
  profiles: profiles ?? FakeProfiles(),
  accounts: accounts ?? FakeAccounts(),
  directory: FakeDirectory(),
  slots: slots ?? FakeSlots(),
);

/// A game loaded and mounted as the app would, with every overlay, so the
/// net callbacks are wired and rounds can run.
Future<TankGame> loadedGame({NetService? net, RoomSlots? slots}) async {
  final game = offlineGame(net: net, slots: slots)
    ..onGameResize(Vector2(1280, 720));
  for (final id in [
    OverlayIds.lobby,
    OverlayIds.countdown,
    OverlayIds.hud,
    OverlayIds.spectator,
    OverlayIds.roundOver,
    OverlayIds.closed,
    OverlayIds.tutorial,
  ]) {
    game.overlays.addEntry(id, (_, _) => const SizedBox());
  }
  // ignore: invalid_use_of_internal_member
  await game.load();
  // ignore: invalid_use_of_internal_member
  game.mount();
  await game.ready();
  game.update(0);
  return game;
}
