import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wargame/src/db/account_service.dart';

/// A token as Supabase issues it, signature left out: only the claims
/// matter here.
String _token(Map<String, dynamic> claims) {
  String part(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part(claims)}.signature';
}

Session _session({required String user, required String token}) => Session(
  accessToken: token,
  tokenType: 'bearer',
  user: User(
    id: user,
    audience: 'authenticated',
    createdAt: DateTime.utc(2026, 10, 9),
    isAnonymous: true,
  ),
);

void main() {
  group('token and user of a session', () {
    test('match when the token was issued for the user', () {
      final session = _session(
        user: '2bfac0bd',
        token: _token({'sub': '2bfac0bd', 'is_anonymous': true}),
      );
      expect(AccountService.tokenMatchesUser(session), isTrue);
    });

    test('differ after another tab swapped its session in', () {
      // Two tabs signed in a fresh guest each at the same moment; an
      // update in one kept the user and took the other tab's token.
      final session = _session(
        user: '2bfac0bd',
        token: _token({'sub': '6995493a', 'is_anonymous': true}),
      );
      expect(AccountService.tokenMatchesUser(session), isFalse);
    });

    test('count as matching when the token cannot be read', () {
      expect(
        AccountService.tokenMatchesUser(
          _session(user: '2bfac0bd', token: 'not-a-jwt'),
        ),
        isTrue,
      );
      expect(
        AccountService.tokenMatchesUser(
          _session(user: '2bfac0bd', token: _token({'role': 'anon'})),
        ),
        isTrue,
      );
    });
  });
}
