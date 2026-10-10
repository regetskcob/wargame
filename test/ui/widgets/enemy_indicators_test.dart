import 'dart:math';

import 'package:flutter/material.dart';
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

  // A 1280 x 800 view with the arrows 30 in from its edge, the gauges in
  // the top left corner and the mini map in the bottom right.
  const inner = Rect.fromLTRB(30, 30, 1250, 770);
  const gauges = Rect.fromLTWH(16, 16, 230, 140);
  const map = Rect.fromLTWH(1110, 620, 150, 150);

  test('an arrow off every plate stays where it points', () {
    const at = Offset(30, 400);
    expect(EnemyIndicators.clearOf(at, const [gauges, map], inner), at);
  });

  test('an arrow on the gauges slides along the edge below them', () {
    final moved = EnemyIndicators.clearOf(const Offset(30, 60), const [
      gauges,
      map,
    ], inner);
    expect(moved.dx, 30);
    expect(moved.dy, greaterThanOrEqualTo(gauges.bottom));
  });

  test('an arrow on the top edge slides beside the gauges', () {
    final moved = EnemyIndicators.clearOf(const Offset(200, 30), const [
      gauges,
    ], inner);
    expect(moved.dy, 30);
    expect(moved.dx, greaterThanOrEqualTo(gauges.right));
  });

  test('an arrow on the map moves off it, inside the view', () {
    final moved = EnemyIndicators.clearOf(const Offset(1250, 700), const [
      gauges,
      map,
    ], inner);
    expect(map.inflate(29).contains(moved), isFalse);
    expect(inner.inflate(1).contains(moved), isTrue);
  });
}
