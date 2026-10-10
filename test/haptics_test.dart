import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <String?>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            calls.add(call.arguments as String?);
          }
          return null;
        });
    Haptics.on.value = true;
    Haptics.resetGaps();
  });

  test('a phone feels the round, unless vibration is switched off', () async {
    // Tests run as Android, so the phone branch is taken.
    expect(Haptics.onPhone, isTrue);
    Haptics.go();
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['HapticFeedbackType.mediumImpact']);

    Haptics.on.value = false;
    Haptics.destroyed();
    Haptics.feel(HapticFeedback.selectionClick);
    await Future<void>.delayed(Duration.zero);
    expect(calls, hasLength(1));
  });

  test('one shake burst taps once, a heavy shake knocks hard', () async {
    Haptics.shake(10);
    Haptics.shake(10);
    Haptics.shake(0.5);
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['HapticFeedbackType.heavyImpact']);
  });

  test('blasts on the field never drown or block the own hits', () {
    var at = DateTime(2026);
    Haptics.now = () => at;
    addTearDown(() => Haptics.now = DateTime.now);
    void wait(int ms) => at = at.add(Duration(milliseconds: ms));

    // A far blast first does not keep the own hit right after from tapping.
    expect(Haptics.admits(6, field: true), isTrue);
    wait(40);
    expect(Haptics.admits(5), isTrue);
    // Right after an own tap the field stays quiet.
    wait(200);
    expect(Haptics.admits(9, field: true), isFalse);
    // A busy field taps at most twice a second, and only when it is felt.
    wait(400);
    var field = 0;
    for (var i = 0; i < 20; i++) {
      if (Haptics.admits(8, field: true)) {
        field++;
      }
      wait(100);
    }
    expect(field, lessThanOrEqualTo(4));
    expect(Haptics.admits(2, field: true), isFalse);
  });
}
