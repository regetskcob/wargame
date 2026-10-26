import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horizont/horizont.dart';
import 'package:wargame/src/ui/theme.dart';
import 'package:wargame/src/ui/widgets/game_dialog.dart';

void main() {
  Future<bool?> ask(WidgetTester tester) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGameTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              answer = await showGameDialog<bool>(
                context: context,
                builder: (context) => AlertDialog.adaptive(
                  title: const Text('KONTO LÖSCHEN?'),
                  actions: [
                    horizontDialogAction(
                      context,
                      label: 'ABBRECHEN',
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    horizontDialogAction(
                      context,
                      label: 'LÖSCHEN',
                      primary: true,
                      destructive: true,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return answer;
  }

  testWidgets('on iOS the dialog is the native one', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await ask(tester);
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(CupertinoDialogAction), findsNWidgets(2));
    await tester.tap(find.text('LÖSCHEN'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('on Android the dialog stays Material with a filled main '
      'action', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await ask(tester);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(find.widgetWithText(FilledButton, 'LÖSCHEN'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
