import 'package:flutter_test/flutter_test.dart';
import 'package:game/src/game/map_theme.dart';
import 'package:game/src/game/weather.dart';

void main() {
  test('weather and time of day can be forced without moving the map', () {
    for (var seed = 0; seed < 2000; seed += 37) {
      for (final sky in Sky.values) {
        for (final night in [true, false]) {
          final forced = Conditions.seedWith(seed, sky: sky, night: night);
          final conditions = Conditions.forSeed(forced);
          expect(conditions.sky, sky);
          expect(conditions.night, night);
          expect(MapTheme.forSeed(forced), MapTheme.forSeed(seed));
        }
      }
    }
  });

  test('a seed without a wish keeps its weather', () {
    for (var seed = 0; seed < 500; seed += 7) {
      expect(Conditions.seedWith(seed), seed);
    }
  });

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
}
