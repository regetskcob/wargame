import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/l10n/l10n.dart';
import 'package:wargame/src/ui/widgets/account_sheet.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../helpers/fakes.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => L10n.lang.value = AppLang.de);

  testWidgets('the language is picked in the account and the sheet follows', (
    tester,
  ) async {
    final game = offlineGame();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => AccountSheet.show(context, game),
            child: const Text('OPEN'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('SPRACHE'), findsOneWidget);
    await tester.tap(find.text('ENGLISH'));
    await tester.pumpAndSettle();

    expect(L10n.current, AppLang.en);
    expect(find.text('LANGUAGE'), findsOneWidget);
    expect(find.text('ACCOUNT'), findsOneWidget);
  });
}
