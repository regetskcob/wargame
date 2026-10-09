import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/env.dart';
import '../l10n/l10n.dart';
import '../net/room.dart';

/// Turns the anonymous guest account every player starts with into a lasting
/// one, by e-mail or with a GitHub or Google login, and signs into such an
/// account on another device. Rounds, rating and badges hang on the account,
/// so they come along.
class AccountService {
  AccountService(this._client) {
    _subscription = _client.auth.onAuthStateChange.listen((_) {
      user.value = _client.auth.currentUser;
    });
  }

  final SupabaseClient _client;

  /// This page was opened from the link in a mail, but the browser could
  /// not finish the sign-in there: the link was opened in another browser,
  /// or in a private tab that does not share storage with the one that asked
  /// for the mail.
  static bool mailLinkFailed = false;
  late final StreamSubscription<AuthState> _subscription;

  late final user = ValueNotifier<User?>(_client.auth.currentUser);

  /// Logins that can be offered next to e-mail, see docs/development.md.
  static const _knownProviders = [
    (OAuthProvider.github, 'GITHUB'),
    (OAuthProvider.google, 'GOOGLE'),
  ];

  /// The logins the Supabase project has switched on. Empty until the
  /// settings arrived, and when none is set up.
  final providers = ValueNotifier<List<(OAuthProvider, String)>>(const []);

  /// Asks the project which logins it offers, so the lobby only shows
  /// buttons that work.
  Future<void> loadProviders() async {
    try {
      final response = await http
          .get(
            Uri.parse('${Env.supabaseUrl}/auth/v1/settings'),
            headers: {'apikey': Env.supabaseKey},
          )
          .timeout(const Duration(seconds: 5));
      final external =
          (jsonDecode(response.body) as Map<String, dynamic>)['external']
              as Map<String, dynamic>;
      providers.value = [
        for (final provider in _knownProviders)
          if (external[provider.$1.name] == true) provider,
      ];
    } on Object catch (error) {
      debugPrint('Loading the login providers failed: $error');
      providers.value = const [];
    }
  }

  bool get isGuest => user.value?.isAnonymous ?? true;

  /// E-mail of the account, or the one waiting for confirmation.
  String? get email => user.value?.email ?? user.value?.newEmail;

  bool get awaitingConfirmation =>
      user.value?.newEmail != null && user.value?.email == null;

  /// Gives the guest account an e-mail address. It lasts once the player
  /// confirms with the link or the code from the mail.
  /// [name] is the call sign, kept with the account so it is there on
  /// every device. The e-mail address itself is never shown to others.
  Future<void> secureWithEmail(String email, {String? name}) async {
    await _updateUser(
      UserAttributes(
        email: email.trim(),
        data: name == null || name.isEmpty ? null : {'call_sign': name},
      ),
      emailRedirectTo: authRedirect(),
    );
    user.value = _client.auth.currentUser;
  }

  /// Marker on the account for the tutorial of the touch controls or of
  /// keyboard and mouse. The two tutorials differ, so each counts on its own.
  static String _tutorialKey({required bool touch}) =>
      touch ? 'tutorial_seen_touch' : 'tutorial_seen_desktop';

  /// Whether the account went through that tutorial, on any device.
  bool tutorialSeen({required bool touch}) =>
      user.value?.userMetadata[_tutorialKey(touch: touch)] == true;

  /// Day the tutorial came. Every visitor gets an account on the first
  /// visit, a guest one at least, so an older account belongs to a player
  /// who knows the game already.
  static final tutorialSince = DateTime.utc(2026, 10, 8);

  /// Whether the account is older than the tutorial.
  bool get olderThanTutorial {
    final created = user.value?.createdAt;
    return created != null && created.isBefore(tutorialSince);
  }

  /// Marks the tutorial as seen on the account, so signing in on another
  /// device does not bring it up again. Guests get the marker too: it stays
  /// when they register.
  Future<void> rememberTutorialSeen({required bool touch}) async {
    if (user.value == null || tutorialSeen(touch: touch)) {
      return;
    }
    try {
      await _updateUser(
        UserAttributes(data: {_tutorialKey(touch: touch): true}),
      );
      user.value = _client.auth.currentUser;
    } on Object catch (error) {
      debugPrint('Keeping the tutorial on the account failed: $error');
      // The browser still remembers it, the account asks again elsewhere.
    }
  }

  /// Marker on the account for the language the player chose.
  static const _languageKey = 'language';

  /// The language kept with the account, so it comes along to every
  /// device. Null until the player had one.
  AppLang? get language {
    final code = user.value?.userMetadata[_languageKey];
    return AppLang.values.where((l) => l.code == code).firstOrNull;
  }

  /// Keeps [lang] with the account. Guests get it too: it stays when they
  /// register.
  Future<void> rememberLanguage(AppLang lang) async {
    if (user.value == null || language == lang) {
      return;
    }
    try {
      await _updateUser(UserAttributes(data: {_languageKey: lang.code}));
      user.value = _client.auth.currentUser;
    } on Object catch (error) {
      debugPrint('Keeping the language on the account failed: $error');
      // The device still remembers it, the account learns it next time.
    }
  }

  /// [GoTrueClient.updateUser] with a repair afterwards. It keeps the
  /// session that is current once the answer arrives and only swaps in the
  /// returned user. When another tab broadcast its own session meanwhile,
  /// as two tabs opened at once and each signing in a fresh guest do, the
  /// result is one user's id with the other one's token, and every write
  /// that sends the id is refused by row level security until a reload.
  /// The refresh token belongs to the token's user, so a refresh puts the
  /// two together again.
  Future<void> _updateUser(
    UserAttributes attributes, {
    String? emailRedirectTo,
  }) async {
    await _client.auth.updateUser(attributes, emailRedirectTo: emailRedirectTo);
    final session = _client.auth.currentSession;
    if (session != null && !tokenMatchesUser(session)) {
      debugPrint('Session token and user differ, refreshing the session');
      try {
        await _client.auth.refreshSession();
      } on Object catch (error) {
        // The update itself went through; the next refresh repairs it.
        debugPrint('Refreshing the session failed: $error');
      }
    }
  }

  /// Whether the access token of [session] was issued for its user. A
  /// token that cannot be read counts as matching, so nothing is repaired
  /// on a guess.
  static bool tokenMatchesUser(Session session) {
    try {
      final payload = session.accessToken.split('.')[1];
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(payload))),
      ) as Map<String, dynamic>;
      final subject = claims['sub'];
      return subject is! String || subject == session.user.id;
    } on Object {
      return true;
    }
  }

  /// Links a GitHub or Google login to the guest account.
  Future<void> secureWith(OAuthProvider provider) async {
    await _client.auth.linkIdentity(provider, redirectTo: authRedirect());
  }

  /// Sends a sign-in mail for an existing account, for another device.
  Future<void> sendSignInMail(String email) async {
    await _client.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: authRedirect(),
      shouldCreateUser: false,
    );
  }

  Future<void> signInWith(OAuthProvider provider) async {
    await _client.auth.signInWithOAuth(provider, redirectTo: authRedirect());
  }

  /// Confirms an e-mail change or a sign-in with the code from the mail.
  Future<void> verifyCode(
    String email,
    String code, {
    required bool signIn,
  }) async {
    await _client.auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: signIn ? OtpType.email : OtpType.emailChange,
    );
    user.value = _client.auth.currentUser;
  }

  /// Fetches the account again, to notice an address that was confirmed
  /// through the mail in another tab or on another device.
  Future<void> refresh() async {
    await _client.auth.refreshSession();
    user.value = _client.auth.currentUser;
  }

  /// Deletes the account with every round, rating, badge and the profile
  /// for good, then plays on as a fresh guest.
  Future<void> deleteAccount() async {
    await _client.rpc<void>('delete_account');
    try {
      // The session belonged to the deleted user, drop it on this device.
      await _client.auth.signOut(scope: SignOutScope.local);
    } on Object {
      // Gone on the server already, nothing left to sign out of.
    }
    await _client.auth.signInAnonymously();
    user.value = _client.auth.currentUser;
  }

  /// Leaves the account and plays on as a fresh guest.
  Future<void> signOut() async {
    await _client.auth.signOut();
    await _client.auth.signInAnonymously();
    user.value = _client.auth.currentUser;
  }

  void dispose() {
    unawaited(_subscription.cancel());
  }
}
