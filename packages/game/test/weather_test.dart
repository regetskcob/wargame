import 'package:flutter_test/flutter_test.dart';
import 'package:game/src/game/map_theme.dart';
import 'package:game/src/game/weather.dart';

void main() {
  test('random seeds bring every kind of weather', () {
    final skies = {for (var s = 0; s < 400; s++) Conditions.forSeed(s).sky};
    final nights = {for (var s = 0; s < 400; s++) Conditions.forSeed(s).night};
    expect(skies, Sky.values.toSet());
    expect(nights, {true, false});
  });

  test('night and fog limit the view, a clear day does not', () {
    Conditions make(Sky sky, bool night) =>
        Conditions(sky: sky, night: night, theme: MapTheme.forest);
    expect(make(Sky.clear, false).vision, isNull);
    expect(make(Sky.precipitation, false).vision, isNull);
    expect(make(Sky.fog, false).vision, isNotNull);
    expect(make(Sky.clear, true).vision, isNotNull);
    expect(make(Sky.fog, true).vision!, lessThan(make(Sky.fog, false).vision!));
  });

  test('the weather starts with the seed and turns in long rounds', () {
    var turned = 0;
    for (var seed = 0; seed < 200; seed++) {
      expect(Conditions.skyAt(seed, 0), Conditions.forSeed(seed).sky);
      expect(
        Conditions.skyAt(seed, Conditions.spell - 1),
        Conditions.forSeed(seed).sky,
      );
      // Every client works out the same sky for the same moment.
      expect(Conditions.skyAt(seed, 500), Conditions.skyAt(seed, 500));
      final skies = {
        for (var t = 0.0; t < 600; t += Conditions.spell)
          Conditions.skyAt(seed, t),
      };
      if (skies.length > 1) {
        turned++;
      }
    }
    expect(turned, greaterThan(100));
  });

  test('day and night take turns at a fixed pace', () {
    const cycle = Conditions.dayLength + Conditions.nightLength;
    for (var seed = 0; seed < 200; seed++) {
      expect(Conditions.nightAt(seed, 0), Conditions.forSeed(seed).night);
      // Every client works out the same light for the same moment.
      expect(Conditions.nightAt(seed, 95), Conditions.nightAt(seed, 95));
      var night = 0;
      var turns = 0;
      var before = Conditions.nightAt(seed, 0);
      for (var t = 0.0; t < cycle * 3; t += 1) {
        final now = Conditions.nightAt(seed, t);
        if (now) {
          night++;
        }
        if (now != before) {
          turns++;
        }
        before = now;
        expect(Conditions.nightAt(seed, t + cycle), now);
      }
      expect(night, closeTo(Conditions.nightLength * 3, 3));
      expect(turns, inInclusiveRange(5, 6));
    }
  });
}
