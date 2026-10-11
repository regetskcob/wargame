import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wargame/src/app/routes.dart';
import 'package:wargame/src/l10n/l10n.dart';
import 'package:wargame/src/tv/tv_input.dart';
import 'package:wargame/src/ui/account_page.dart';
import 'package:wargame/src/ui/theme.dart';
import 'package:wargame/src/ui/widgets/legal.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/fakes.dart';
import '../helpers/router_app.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => L10n.lang.value = AppLang.de);

  testWidgets('the account is a page of the router with one way to close it', (
    tester,
  ) async {
    final game = offlineGame();
    await pumpRouterApp(tester, game, AccountButton(game: game));
    await tester.tap(find.byType(AccountButton));
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(AccountPage)));
    expect(router.state.uri.path, Routes.account);
    // The guest's securing is open from the start and has no close of its
    // own next to the page's.
    expect(find.text('SCHLIESSEN'), findsNothing);
    expect(find.byTooltip('Schließen'), findsOneWidget);

    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountPage), findsNothing);
    expect(find.byType(AccountButton), findsOneWidget);
  });

  testWidgets('the language is picked in the title line of the account and '
      'everything follows, the page behind and const widgets too', (
    tester,
  ) async {
    final game = offlineGame();
    await pumpRouterApp(
      tester,
      game,
      Column(
        children: [
          AccountButton(game: game),
          const LegalLinks(),
        ],
      ),
    );
    await tester.tap(find.byType(AccountButton));
    await tester.pumpAndSettle();

    expect(find.text('KONTO'), findsOneWidget);
    await tester.tap(find.text('ENGLISH'));
    await tester.pumpAndSettle();

    expect(L10n.current, AppLang.en);
    // The chip itself shows the new choice, not only the texts around it.
    Color? colorOf(String label) =>
        tester.widget<Text>(find.text(label)).style?.color;
    expect(colorOf('ENGLISH'), GameColors.amber);
    expect(colorOf('DEUTSCH'), GameColors.text);
    expect(find.text('ACCOUNT'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    // The legal links on the page behind are const and were not rebuilt by
    // anything but the change of language.
    expect(find.text('Legal notice'), findsOneWidget);
    expect(find.text('Impressum'), findsNothing);
  });

  testWidgets('a tall tablet shows the account and the device side by side '
      'without scrolling', (tester) async {
    addTearDown(tester.view.reset);
    tester.view
      ..physicalSize = const Size(1024, 1366)
      ..devicePixelRatio = 1;
    final game = offlineGame();
    await pumpRouterApp(tester, game, AccountButton(game: game));
    await tester.tap(find.byType(AccountButton));
    await tester.pumpAndSettle();

    final field = tester.getRect(find.widgetWithText(TextField, 'RUFNAME'));
    final legal = tester.getRect(find.byType(LegalLinks));
    // Two columns: the legal links at the foot of the right one, level with
    // the call sign at the top of the left.
    expect(legal.left, greaterThan(field.right));
    final scroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(AccountPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scroll.position.maxScrollExtent, 0);
  });

  testWidgets('a television shows the account in two columns and starts '
      'the remote on the close button', (tester) async {
    onAndroidTvForTesting = true;
    addTearDown(() => onAndroidTvForTesting = false);
    addTearDown(tester.view.reset);
    tester.view
      ..physicalSize = const Size(1371, 771)
      ..devicePixelRatio = 1;
    final game = offlineGame();
    await pumpRouterApp(tester, game, AccountButton(game: game));
    await tester.tap(find.byType(AccountButton));
    await tester.pumpAndSettle();

    final field = tester.getRect(find.widgetWithText(TextField, 'RUFNAME'));
    final legal = tester.getRect(find.byType(LegalLinks));
    expect(legal.left, greaterThan(field.right));
    final close = tester.element(find.byIcon(Icons.close_outlined));
    expect(Focus.of(close).hasFocus, isTrue);
  });
}
