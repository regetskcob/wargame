import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/ui/widgets/enemy_indicators.dart';

void main() {
  test('distance is shown in steps of five metres', () {
    expect(indicatorMetres(0), 0);
    expect(indicatorMetres(240), 25);
    expect(indicatorMetres(260), 25);
    expect(indicatorMetres(280), 30);
    expect(indicatorMetres(1234), 125);
  });

  test('arrows turn the shorter way round', () {
    // From just below +pi to just above -pi crosses the seam, not the middle.
    final turned = approachAngle(pi - 0.1, -pi + 0.1, 0.5);
    expect(cos(turned), closeTo(-1, 1e-9));
    expect(approachAngle(0, 1, 0.5), closeTo(0.5, 1e-9));
    expect(approachAngle(1, 1, 0.3), 1);
  });
}
