import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_watch_link/flutter_watch_link.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The account of the iPhone app, lent to the Apple Watch.
///
/// The watch is not signed in on its own: typing an address on the wrist is
/// no way to play. The phone hands over who is signed in there and a fresh
/// access token whenever it has one; the watch plays under that account and
/// records its rounds with that token.
///
/// Only the access token travels, never the refresh token. Supabase turns
/// refresh tokens over on every use, and two devices using the same one
/// would sign each other out. An access token lasts an hour; a round that
/// ends without a valid one waits on the watch (see [PendingRounds]) until
/// the phone sends the next.
@immutable
class LinkedAccount {
  const LinkedAccount({
    required this.userId,
    required this.name,
    required this.token,
    required this.expiresAt,
  });

  /// The account's id, the `sub` of [token].
  final String userId;

  /// Its call sign, shown on the watch instead of the guest's.
  final String name;

  final String token;

  /// When [token] runs out.
  final DateTime expiresAt;

  /// Whether [token] still lasts a minute, long enough for one call.
  bool get usable =>
      clock.now().isBefore(expiresAt.subtract(const Duration(minutes: 1)));

  Map<String, Object?> toJson() => {
    'user': userId,
    'name': name,
    'token': token,
    'expires': expiresAt.millisecondsSinceEpoch,
  };

  /// Null for anything that is no signed in account: no token, a guest's,
  /// or not a map at all. Payloads come over the link and from storage.
  static LinkedAccount? tryParse(Object? json) {
    if (json is! Map) {
      return null;
    }
    final user = json['user'];
    final name = json['name'];
    final token = json['token'];
    final expires = json['expires'];
    if (user is! String ||
        user.isEmpty ||
        token is! String ||
        token.isEmpty ||
        expires is! int) {
      return null;
    }
    return LinkedAccount(
      userId: user,
      name: name is String && name.trim().isNotEmpty ? name.trim() : '',
      token: token,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expires),
    );
  }

  /// What the phone hands over for [session]: null for a guest or nobody.
  static LinkedAccount? ofSession(Session? session, {String name = ''}) {
    final user = session?.user;
    final expires = session?.expiresAt;
    if (session == null || user == null || user.isAnonymous) {
      return null;
    }
    return LinkedAccount(
      userId: user.id,
      name: name.isNotEmpty
          ? name
          : (user.userMetadata['call_sign'] as String? ?? ''),
      token: session.accessToken,
      expiresAt: expires ?? clock.now().add(const Duration(minutes: 50)),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LinkedAccount &&
      other.userId == userId &&
      other.name == name &&
      other.token == token &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(userId, name, token, expiresAt);
}

/// Both ends of the link, over WatchConnectivity.
class AccountLink {
  AccountLink._();

  static final instance = AccountLink._();

  static const _storeKey = 'panzergefecht.linkedAccount';

  /// On the watch: the phone's account, null while the phone has none (or
  /// never said). Kept across restarts.
  final account = ValueNotifier<LinkedAccount?>(null);

  bool _started = false;

  /// The phone's connection, kept for [nameChangedOnPhone].
  SupabaseClient? _client;

  /// The phone's call sign, read when the account is handed over.
  String Function() _name = () => '';

  /// The phone: hands the signed in account of [client] to the watch on
  /// every change of the session and answers the watch's asking. [name]
  /// gives the call sign in use. Does nothing without a paired watch.
  Future<void> startOnPhone(
    SupabaseClient client, {
    required String Function() name,
  }) async {
    if (_started || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    _started = true;
    _client = client;
    _name = name;
    try {
      final link = WatchLink.instance;
      if (!await link.isSupported()) {
        _client = null;
        debugPrint('Account link: no watch on this device');
        return;
      }
      link.messages.listen((message) async {
        if (message.expectsReply && message.payload['get'] == 'account') {
          await message.reply(_current());
        }
      });
      final state = await _activate(link);
      debugPrint(
        'Account link: watch paired ${state.counterpartPaired}, '
        'app installed ${state.counterpartInstalled}',
      );
      client.auth.onAuthStateChange.listen((_) => unawaited(_push()));
      await _push();
    } on Object catch (error) {
      debugPrint('Account link unavailable: $error');
    }
  }

  Map<String, Object?> _current() =>
      LinkedAccount.ofSession(
        _client?.auth.currentSession,
        name: _name(),
      )?.toJson() ??
      const {'token': null};

  Future<void> _push() async {
    if (_client == null) {
      return;
    }
    try {
      await WatchLink.instance.updateApplicationContext(_current());
    } on Object catch (error) {
      // No watch paired, or its app not installed: nothing to tell.
      debugPrint('Account link: $error');
    }
  }

  /// The phone: the call sign changed, the watch shows the new one.
  void nameChangedOnPhone() => unawaited(_push());

  /// The watch: takes the account the phone sent last, listens for the
  /// next, and asks the phone for a fresh one.
  Future<void> startOnWatch() async {
    if (_started) {
      return;
    }
    _started = true;
    account.value = await _load();
    try {
      final link = WatchLink.instance;
      link.messages.listen((message) => _take(message.payload));
      final state = await _activate(link);
      final context = await link.receivedApplicationContext();
      debugPrint(
        'Account link: phone app installed ${state.counterpartInstalled}, '
        'reachable ${state.reachable}, context ${context?.keys.toList()}',
      );
      if (context != null) {
        _take(context);
      }
      await refresh();
    } on Object catch (error) {
      debugPrint('Account link unavailable: $error');
    }
  }

  /// Activates the session and waits until it is: `activate` returns
  /// before WatchConnectivity is done, and a send before that throws.
  static Future<WatchLinkState> _activate(WatchLink link) async {
    final activated = link.states
        .firstWhere((state) => state.activated)
        .timeout(const Duration(seconds: 10));
    await link.activate();
    final now = await link.readState();
    if (now.activated) {
      // Not waited for: its time-out must not surface as an error.
      activated.ignore();
      return now;
    }
    return activated;
  }

  /// The watch: asks the phone for the account and a fresh token, when the
  /// phone app can be reached. True when one came.
  Future<bool> refresh() async {
    try {
      final link = WatchLink.instance;
      final state = await link.readState();
      if (!state.activated || !state.reachable) {
        return false;
      }
      final reply = await link.sendMessageWithReply({'get': 'account'});
      _take(reply);
      return account.value?.usable ?? false;
    } on Object catch (error) {
      debugPrint('Account link: asking the phone failed: $error');
      return false;
    }
  }

  /// A payload from the phone: an account, or none any more.
  @visibleForTesting
  void take(Map<String, Object?> payload) => _take(payload);

  void _take(Map<String, Object?> payload) {
    if (!payload.containsKey('token')) {
      return;
    }
    final linked = LinkedAccount.tryParse(payload);
    if (linked == account.value) {
      return;
    }
    account.value = linked;
    unawaited(_save(linked));
  }

  static Future<LinkedAccount?> _load() async {
    try {
      final text = await SharedPreferencesAsync().getString(_storeKey);
      return text == null ? null : LinkedAccount.tryParse(jsonDecode(text));
    } on Object {
      return null;
    }
  }

  static Future<void> _save(LinkedAccount? linked) async {
    try {
      final store = SharedPreferencesAsync();
      if (linked == null) {
        await store.remove(_storeKey);
      } else {
        await store.setString(_storeKey, jsonEncode(linked.toJson()));
      }
    } on Object {
      // The link is then only good until the watch app closes.
    }
  }
}
