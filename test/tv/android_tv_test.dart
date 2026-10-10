import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/tv/tv_input.dart';
import 'package:wargame/src/ui/widgets/tablet_scale.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('wargame/tv');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    onAndroidTvForTesting = false;
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('Android asks the native side whether it is a television', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'info' ? {'tv': true} : null,
    );
    await detectTv();
    expect(onTv, isTrue);
    expect(onAppleTv, isFalse);
    expect(remoteName, isNot('Siri Remote'));
  });

  test('a phone stays a phone, also without the question', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(channel, (call) async => {'tv': false});
    await detectTv();
    expect(onTv, isFalse);

    messenger.setMockMethodCallHandler(channel, null);
    await detectTv();
    expect(onTv, isFalse);
  });

  test('only Android asks', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var asked = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      asked = true;
      return {'tv': true};
    });
    await detectTv();
    expect(asked, isFalse);
    expect(onTv, isFalse);
  });

  test('every television lays the menus out 1371 points wide', () {
    expect(tvScaleFor(const Size(1920, 1080)), tvScale);
    final android = tvScaleFor(const Size(960, 540));
    expect(960 / android, closeTo(1920 / tvScale, 1e-9));
  });
}
