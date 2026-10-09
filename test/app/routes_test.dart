import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/app/routes.dart';

void main() {
  test('the pad location carries the code and the name', () {
    expect(Routes.pad('ABCD'), '/pad/ABCD');
    expect(Routes.pad('ABCD', name: 'Wolf 1'), '/pad/ABCD?name=Wolf+1');
  });

  testWidgets('an unknown location falls back to the game', (tester) async {
    final router = buildRouter(game: (_) => const Text('game'));
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('game'), findsOneWidget);

    router.go('/nowhere');
    await tester.pumpAndSettle();
    expect(find.text('game'), findsOneWidget);
    expect(router.state.uri.path, Routes.game);
  });
}
