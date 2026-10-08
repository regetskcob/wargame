import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/ui/widgets/tablet_scale.dart';

void main() {
  test('phones keep the HUD size, tablets grow it up to 1.4', () {
    expect(hudScaleFor(const Size(844, 390)), 1);
    expect(hudScaleFor(const Size(390, 844)), 1);
    expect(hudScaleFor(const Size(1194, 834)), closeTo(1.4, 1e-9));
    expect(hudScaleFor(const Size(700, 600)), closeTo(600 / 430, 1e-9));
  });

  testWidgets('a tablet lays the HUD out on the smaller screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Size? seen;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData.fromView(tester.view),
          child: TabletScale(
            child: Builder(
              builder: (context) {
                seen = MediaQuery.sizeOf(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    expect(seen!.height, closeTo(800 / 1.4, 1e-6));
    expect(seen!.width, closeTo(1200 / 1.4, 1e-6));
  });
}
