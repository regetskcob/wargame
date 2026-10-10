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
}
