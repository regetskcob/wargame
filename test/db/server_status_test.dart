import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wargame/src/db/server_status.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/l10n/l10n.dart';
import 'package:wargame/src/net/room.dart';
import 'package:wargame/src/ui/launch_view.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/fakes.dart';

/// What PostgREST answers once Supabase restricts a project over its
/// quota: every request fails with 402.
const _restricted = PostgrestApiException(
  message: 'Payment required',
  statusCode: 402,
);

/// An auth client without a session whose guest sign-in waits for [done].
class _SlowAuth implements AuthClient {
  final done = Completer<Session>();
  var signIns = 0;

  @override
  Session? get currentSession => null;

  @override
  Future<Session> signInAnonymously({
    Map<String, dynamic>? data,
    String? captchaToken,
  }) {
    signIns++;
    return done.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('the start and the first heartbeat share one guest sign-in', () async {
    final auth = _SlowAuth();
    final first = ServerStatus.ensureSession(auth);
    final second = ServerStatus.ensureSession(auth);
    auth.done.completeError(Exception('offline'));
    expect(await first, isFalse);
    expect(await second, isFalse);
    expect(auth.signIns, 1);
  });

  group('asking the server', () {
    Future<bool> ok() async => true;
    Future<void> beat() async {}

    test('a heartbeat that gets through means online', () async {
      expect(await ServerStatus.check(session: ok, heartbeat: beat), isTrue);
    });

    test(
      'no session, as when the anonymous sign-in failed, means offline',
      () async {
        var beats = 0;
        final online = await ServerStatus.check(
          session: () async => false,
          heartbeat: () async => beats++,
        );
        expect(online, isFalse);
        expect(beats, 0);
      },
    );

    test('a project over its quota means offline', () async {
      final online = await ServerStatus.check(
        session: ok,
        heartbeat: () async => throw _restricted,
      );
      expect(online, isFalse);
    });

    test('no network means offline', () async {
      final online = await ServerStatus.check(
        session: ok,
        heartbeat: () async => throw Exception('Failed host lookup'),
      );
      expect(online, isFalse);
    });

    test('an address that is none means offline', () async {
      // Build 4: a stored session, but every request failed on its URL.
      final online = await ServerStatus.check(
        session: ok,
        heartbeat: () async => throw const FormatException('Invalid host'),
      );
      expect(online, isFalse);
    });

    test('a heartbeat that hangs means offline after the timeout', () {
      fakeAsync((async) {
        bool? online;
        ServerStatus.check(
          session: ok,
          heartbeat: () => Completer<void>().future,
        ).then((value) => online = value);
        async.elapse(ServerStatus.timeout - const Duration(seconds: 1));
        expect(online, isNull);
        async.elapse(const Duration(seconds: 2));
        expect(online, isFalse);
      });
    });

    test('a database without the heartbeat still counts as there', () async {
      final online = await ServerStatus.check(
        session: ok,
        heartbeat: () async => throw const PostgrestApiException(
          message: 'Could not find the function',
          statusCode: 404,
          errorCode: 'PGRST202',
        ),
      );
      expect(online, isTrue);
    });
  });

  group('the start page without a server', () {
    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await openLocalStore();
      L10n.lang.value = AppLang.de;
    });

    tearDown(() => ServerStatus.available.value = true);

    Future<TankGame> show(WidgetTester tester, {required bool online}) async {
      ServerStatus.available.value = online;
      final game = offlineGame()..changeMode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: LaunchView(game: game)),
          ),
        ),
      );
      await tester.pump();
      return game;
    }

    testWidgets('says why and keeps single player open', (tester) async {
      final game = await show(tester, online: false);
      expect(find.textContaining('nicht verfügbar'), findsOneWidget);
      expect(find.text('GERADE NICHT VERFÜGBAR'), findsOneWidget);

      await tester.tap(find.text('MEHRSPIELER'));
      await tester.pump();
      expect(game.choosingMode.value, isTrue, reason: 'still on the page');

      await tester.tap(find.text('EINZELSPIELER'));
      await tester.pump();
      expect(game.choosingMode.value, isFalse);
      expect(game.mode.value, GameMode.solo);
    });

    testWidgets('with the server back the notice is gone', (tester) async {
      final game = await show(tester, online: true);
      expect(find.textContaining('nicht verfügbar'), findsNothing);
      await tester.tap(find.text('MEHRSPIELER'));
      await tester.pump();
      expect(game.mode.value, GameMode.multi);
      expect(game.choosingMode.value, isFalse);
    });
  });
}
