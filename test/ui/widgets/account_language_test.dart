import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/l10n/l10n.dart';
import 'package:wargame/src/ui/theme.dart';
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

  testWidgets('the language is picked in the title line of the account and the '
      'sheet follows', (tester) async {
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
  });
}
