import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  late final StreamSubscription<AuthState> _subscription;

  late final user = ValueNotifier<User?>(_client.auth.currentUser);

  /// Logins offered next to e-mail. They have to be enabled in the Supabase
  /// project, see the README.
  static const providers = [
    (OAuthProvider.github, 'GITHUB'),
    (OAuthProvider.google, 'GOOGLE'),
  ];

  bool get isGuest => user.value?.isAnonymous ?? true;

  /// E-mail of the account, or the one waiting for confirmation.
  String? get email => user.value?.email ?? user.value?.newEmail;

  bool get awaitingConfirmation =>
      user.value?.newEmail != null && user.value?.email == null;

  /// Gives the guest account an e-mail address. It lasts once the player
  /// confirms with the link or the code from the mail.
  Future<void> secureWithEmail(String email) async {
    await _client.auth.updateUser(
      UserAttributes(email: email.trim()),
      emailRedirectTo: authRedirect(),
    );
    user.value = _client.auth.currentUser;
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
