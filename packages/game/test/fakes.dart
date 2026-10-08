import 'package:flutter/foundation.dart';
import 'package:game/src/db/account_service.dart';
import 'package:game/src/db/profile_service.dart';
import 'package:game/src/db/score_service.dart';
import 'package:game/src/game/space_game.dart';
import 'package:game/src/net/net_service.dart';
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A game that never connects: enough for the pages around it.
SpaceGame offlineGame({AccountService? accounts, ProfileService? profiles}) =>
    SpaceGame(
      net: NetService(myId: 'me', room: 'TEST1'),
      myId: 'me',
      scoreService: FakeScores(),
      profiles: profiles ?? FakeProfiles(),
      accounts: accounts ?? FakeAccounts(),
    );
