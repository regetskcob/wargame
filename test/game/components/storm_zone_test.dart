import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/components/storm_zone.dart';
import 'package:wargame/src/game/game_config.dart';

/// Feedback from 1.1.0: alone in the closed zone a round ran on until the
/// player drove out to end it. The zone now draws in to nothing.
void main() {
  int at(double seconds) => (seconds * 1000).round();

  test('the zone closes, holds, then draws in to nothing', () {
    expect(StormZone.radiusAt(0, at(10)), GameConfig.worldRadius);
    expect(
      StormZone.radiusAt(0, at(StormZone.closedAfter)),
      GameConfig.zoneMinRadius,
    );
    expect(
      StormZone.radiusAt(0, at(StormZone.finalAfter - 1)),
      GameConfig.zoneMinRadius,
    );
    final halfway = StormZone.radiusAt(
      0,
      at(StormZone.finalAfter + GameConfig.zoneFinalSeconds / 2),
    );
    expect(halfway, closeTo(GameConfig.zoneMinRadius / 2, 0.01));
    expect(
      StormZone.radiusAt(
        0,
        at(StormZone.finalAfter + GameConfig.zoneFinalSeconds + 60),
      ),
      0,
    );
  });

  test('the damage stays steady while closing and rises once closed', () {
    expect(StormZone.damageAt(0, at(30)), GameConfig.zoneDamagePerSecond);
    expect(
      StormZone.damageAt(0, at(StormZone.closedAfter)),
      GameConfig.zoneDamagePerSecond,
    );
    final later = StormZone.damageAt(0, at(StormZone.closedAfter + 60));
    expect(
      later,
      GameConfig.zoneDamagePerSecond + 60 * GameConfig.zoneDamageRampPerSecond,
    );
  });
}
