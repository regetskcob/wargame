import 'package:flutter_test/flutter_test.dart';
import 'package:game/src/game/components/tank_painter.dart';
import 'package:game/src/ui/widgets/tank_choice.dart';

void main() {
  test('vehicles are listed by unlock rank, then by strength', () {
    final order = StatBars.byUnlock;
    expect(order.toSet(), TankType.values.toSet());
    for (var i = 1; i < order.length; i++) {
      final a = order[i - 1];
      final b = order[i];
      expect(a.level, lessThanOrEqualTo(b.level));
      if (a.level == b.level) {
        expect(
          StatBars.strengthOf(a),
          lessThanOrEqualTo(StatBars.strengthOf(b)),
        );
      }
    }
  });
}
