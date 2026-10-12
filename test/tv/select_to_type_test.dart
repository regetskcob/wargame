import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/tv/select_to_type.dart';
import 'package:wargame/src/tv/tv_input.dart';

void main() {
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextButton(onPressed: () {}, child: const Text('above')),
            SelectToType(
              builder: (focusNode, readOnly) =>
                  TextField(focusNode: focusNode, readOnly: readOnly),
            ),
            TextButton(onPressed: () {}, child: const Text('below')),
          ],
        ),
      ),
    ),
  );

  EditableText field(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText));

  tearDown(() => onAndroidTvForTesting = false);

  testWidgets('on a television the focus passes without a keyboard', (
    tester,
  ) async {
    onAndroidTvForTesting = true;
    await pump(tester);
    field(tester).focusNode.requestFocus();
    await tester.pump();

    // Read-only: no input connection, so the Apple TV's keyboard stand-in
    // never gets between the remote and the end of the swipe.
    expect(field(tester).focusNode.hasFocus, isTrue);
    expect(field(tester).readOnly, isTrue);
    expect(tester.testTextInput.hasAnyClients, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(field(tester).readOnly, isFalse);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('closing the keyboard leaves the focus on the field', (
    tester,
  ) async {
    onAndroidTvForTesting = true;
    await pump(tester);
    field(tester).focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    tester.testTextInput.closeConnection();
    await tester.pump();
    await tester.pump();

    expect(field(tester).focusNode.hasFocus, isTrue);
    expect(field(tester).readOnly, isTrue);
  });

  testWidgets('elsewhere the field types at once', (tester) async {
    await pump(tester);
    field(tester).focusNode.requestFocus();
    await tester.pump();
    expect(field(tester).readOnly, isFalse);
    expect(tester.testTextInput.hasAnyClients, isTrue);
  });
}
