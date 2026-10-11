import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/audio/engine_throttle.dart';

void main() {
  test('a steady engine sends its level once', () {
    final throttle = EngineThrottle();
    expect(throttle.next(0.5), 0.5);
    throttle.done();
    // Ten times a second at the same speed, give or take a tremor.
    for (var i = 0; i < 50; i++) {
      expect(throttle.next(0.5 + (i.isEven ? 0.01 : -0.01)), isNull);
    }
  });

  test('a change goes out rounded, and only after the last one is through', () {
    final throttle = EngineThrottle();
    expect(throttle.next(0.2), 0.2);
    // Still on its way: nothing queues behind it.
    expect(throttle.next(0.9), isNull);
    throttle.done();
    expect(throttle.next(0.93), 0.95);
    throttle.done();
    expect(throttle.next(-1), 0.0);
    throttle.done();
    expect(throttle.next(3), 1.0);
  });

  test('a new loop takes the next level whatever it is', () {
    final throttle = EngineThrottle();
    expect(throttle.next(0.4), 0.4);
    throttle
      ..done()
      ..reset();
    expect(throttle.next(0.4), 0.4);
  });
}
