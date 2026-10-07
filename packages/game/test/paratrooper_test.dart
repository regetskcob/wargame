import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/src/game/components/soldier.dart';
import 'package:game/src/game_config.dart';

/// A field whose round started [secondsAgo] seconds ago, a few frames in.
Future<SoldierField> _field(
  WidgetTester tester,
  int seed,
  double secondsAgo,
) async {
  final game = FlameGame();
  final startedAt =
      DateTime.now().millisecondsSinceEpoch - (secondsAgo * 1000).round();
  final field = SoldierField(seed: seed, startedAt: startedAt);
  game.world.add(field);
  await tester.pumpWidget(GameWidget(game: game, key: UniqueKey()));
  // The first frames mount the field, build it and let a due wave drop in.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  return field;
}

void main() {
  const total = GameConfig.paraWaves * GameConfig.paraPerWave;

  testWidgets('paratroopers land at the same spots on every client', (
    tester,
  ) async {
    final a = await _field(tester, 42, 0);
    final b = await _field(tester, 42, 0);
    final paraA = a.soldiers.where((s) => s.dropAt != null).toList();
    final paraB = b.soldiers.where((s) => s.dropAt != null).toList();
    expect(paraA, hasLength(total));
    for (var i = 0; i < paraA.length; i++) {
      expect(paraA[i].index, paraB[i].index);
      expect(paraA[i].home, paraB[i].home);
      expect(paraA[i].dropAt, paraB[i].dropAt);
    }
  });

  testWidgets('they are not on the map before their wave', (tester) async {
    final field = await _field(tester, 7, 1);
    final para = field.soldiers.where((s) => s.dropAt != null);
    expect(para.where((s) => s.isMounted), isEmpty);
  });

  testWidgets('a wave hangs in the air, then lands and walks', (tester) async {
    final falling = await _field(tester, 7, GameConfig.paraFirstWave + 1);
    final first = falling.soldiers
        .where((s) => s.dropAt == GameConfig.paraFirstWave)
        .toList();
    expect(first, hasLength(GameConfig.paraPerWave));
    expect(first.every((s) => s.isMounted && s.airborne), isTrue);

    final landed = await _field(
      tester,
      7,
      GameConfig.paraFirstWave + GameConfig.paraFallSeconds + 1,
    );
    final down = landed.soldiers
        .where((s) => s.dropAt == GameConfig.paraFirstWave)
        .toList();
    expect(down.every((s) => s.isMounted && !s.airborne), isTrue);
    final later = landed.soldiers.where(
      (s) => s.dropAt != null && s.dropAt! > GameConfig.paraFirstWave,
    );
    expect(later.where((s) => s.isMounted), isEmpty);
  });
}
