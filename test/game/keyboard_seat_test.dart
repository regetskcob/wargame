import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/tv/seats.dart';
import 'package:wargame/src/tv/tv_input.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void oneController() => TvInput.instance.receive({
    'pads': [
      {'kind': 'gamepad'},
    ],
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    KeyboardSeat.enabled.value = false;
    TvInput.instance.receive({'pads': []});
  });

  test('on a computer the keyboard takes the first seat once switched on, '
      'so one controller is enough for two', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    oneController();
    expect(duelSeats(), hasLength(1), reason: 'alone until switched on');
    KeyboardSeat.enabled.value = true;
    final seats = duelSeats();
    expect(seats, hasLength(2));
    expect(seats.first.keyboard, isTrue);
    expect(seats.first.pad, -1, reason: 'no controller steers player one');
    expect(seats[1].kind, TvPadKind.gamepad);
  });

  test('phones and tablets have no keyboard seat', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    oneController();
    KeyboardSeat.enabled.value = true;
    expect(KeyboardSeat.available, isFalse);
    expect(duelSeats().where((seat) => seat.keyboard), isEmpty);
  });
}
