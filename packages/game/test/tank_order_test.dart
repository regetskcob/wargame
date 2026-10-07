import 'package:flutter_test/flutter_test.dart';
import 'package:game/src/game/components/tank_painter.dart';
import 'package:game/src/ui/widgets/tank_choice.dart';

void main() {
  test('unlocked vehicles come first, each group by strength', () {
    for (final rank in [1, 2, 3, 5, 8]) {
      bool unlocked(TankType type) => rank >= type.level;
      final order = StatBars.ordered(unlocked);
      expect(order.toSet(), TankType.values.toSet());
      for (var i = 1; i < order.length; i++) {
        final a = order[i - 1];
        final b = order[i];
        expect(unlocked(b) && !unlocked(a), isFalse);
        if (unlocked(a) == unlocked(b)) {
          expect(
            StatBars.strengthOf(a),
            lessThanOrEqualTo(StatBars.strengthOf(b)),
          );
        }
      }
    }
  });
}
