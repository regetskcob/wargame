import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/ui/loading_view.dart';

void main() {
  testWidgets('shows the tank of the launch screen on its ground', (
    tester,
  ) async {
    await tester.runAsync(LoadingView.loadImages);
    expect(LoadingView.ground, isNotNull);
    expect(LoadingView.tank, isNotNull);
    await tester.pumpWidget(const LoadingApp());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final images = tester.widgetList<RawImage>(find.byType(RawImage)).toList();
    expect(images.first.image, same(LoadingView.ground));
    expect(images.last.image, same(LoadingView.tank));
    // Same size and place as on the launch screen.
    final tank = find.byType(RawImage).last;
    expect(tester.getSize(tank).width, LoadingView.tankWidth);
    expect(tester.getCenter(tank), tester.getCenter(find.byType(LoadingApp)));
  });
}
