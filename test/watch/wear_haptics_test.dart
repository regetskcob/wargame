import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/haptics.dart';
import 'package:wargame/src/watch/wear_crown.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('wargame/wear');
  final calls = <String?>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'vibrate') {
            calls.add(call.arguments as String?);
          }
          return true;
        });
  });

  tearDown(() {
    onWearForTesting = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('a Wear OS watch taps the wrist for the moments of a round', () async {
    onWearForTesting = true;
    Haptics.tick();
    Haptics.go();
    Haptics.destroyed();
    Haptics.roundOver(won: true);
    await pumpEventQueue();
    expect(calls, ['click', 'start', 'failure', 'success']);
  });

  test(
    'a heavy shake is a stronger tap than a light one, small ones none',
    () async {
      onWearForTesting = true;
      Haptics.shake(0.5);
      Haptics.shake(10);
      await pumpEventQueue();
      expect(calls, ['notification']);
    },
  );

  test('a phone never vibrates', () async {
    Haptics.tick();
    Haptics.shake(10);
    await pumpEventQueue();
    expect(calls, isEmpty);
  });
}
