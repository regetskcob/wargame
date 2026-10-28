import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:horizont/horizont.dart';
import 'package:wargame/src/app/routes.dart';
import 'package:wargame/src/l10n/l10n.dart';
import 'package:wargame/src/tv/tv_input.dart';
import 'package:wargame/src/ui/account_page.dart';
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
    // The chip itself shows the new choice, not only the texts around it:
    // the chosen one is Horizont's selection.
    bool chosen(String label) => tester
        .widget<HorizontSelectable>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(HorizontSelectable),
          ),
        )
        .selected;

    expect(chosen('ENGLISH'), isTrue);
    expect(chosen('DEUTSCH'), isFalse);
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

    final field = tester.getRect(
      find.descendant(
        of: find.widgetWithText(HorizontField, 'Rufname'),
        matching: find.byType(TextField),
      ),
    );
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

    final field = tester.getRect(
      find.descendant(
        of: find.widgetWithText(HorizontField, 'Rufname'),
        matching: find.byType(TextField),
      ),
    );
    final legal = tester.getRect(find.byType(LegalLinks));
    expect(legal.left, greaterThan(field.right));
    final close = tester.element(find.byIcon(HorizontSymbols.close));
    expect(Focus.of(close).hasFocus, isTrue);
  });

  // Issue 21: deleting the account sat between the account and the
  // settings. It belongs below everything one comes to the page for, only
  // the legal links follow it.
  for (final size in const [Size(390, 844), Size(1024, 1366)]) {
    testWidgets('deleting the account comes last on the page ($size)', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      final game = offlineGame();
      await pumpRouterApp(tester, game, AccountButton(game: game));
      await tester.tap(find.byType(AccountButton));
      await tester.pumpAndSettle();

      final delete = tester.getRect(
        find.widgetWithText(OutlinedButton, 'KONTO LÖSCHEN'),
      );
      final legal = tester.getRect(find.byType(LegalLinks));
      expect(legal.top, greaterThanOrEqualTo(delete.bottom));
      final controls = find.descendant(
        of: find.byType(AccountPage),
        matching: find.byWidgetPredicate(
          (w) => w is ButtonStyleButton || w is TextField || w is Switch,
        ),
      );
      expect(controls.evaluate().length, greaterThan(3));
      for (final element in controls.evaluate()) {
        final box = element.renderObject! as RenderBox;
        final rect = box.localToGlobal(Offset.zero) & box.size;
        // In two columns only the column of the button counts.
        if (rect.right <= delete.left || rect.overlaps(legal)) {
          continue;
        }
        expect(
          rect.top,
          lessThanOrEqualTo(delete.top),
          reason: '${element.widget} below the delete button',
        );
      }
    });
  }
}
