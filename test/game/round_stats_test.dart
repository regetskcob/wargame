import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/round_stats.dart';

void main() {
  test('only the own shells count as hits, each once', () {
    final stats = RoundStats()
      ..fired('me-1')
      ..fired('me-2')
      // A gun's shell, a blast and the same shell reported twice.
      ..hit(20, bulletId: 'me-7')
      ..hit(30)
      ..hit(10, bulletId: 'me-1')
      ..hit(10, bulletId: 'me-1');
    expect(stats.shots, 2);
    expect(stats.hits, 1);
    expect(stats.damage, 70);
    expect(stats.accuracy, 0.5);
  });

  test('the accuracy never passes 100 %', () {
    final stats = RoundStats()
      ..shots = 2
      ..hits = 5;
    expect(stats.accuracy, 1);
  });
}
