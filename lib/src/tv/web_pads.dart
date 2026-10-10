import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Reads the controllers of the browser through its Gamepad API and hands
/// [onReport] the same report the native side of the apps sends:
/// `{pads: [{kind: gamepad, lx, ly, rx, ry, a, b, …}]}`.
///
/// The browser does not announce a change: the controllers are read sixty
/// times a second and a report goes out when something differs. A browser
/// only shows a controller once a button on it was pressed.
Object? startWebPads(void Function(Map<Object?, Object?> report) onReport) {
  var last = '';
  return Timer.periodic(const Duration(milliseconds: 16), (_) {
    final List<Map<String, Object>> pads;
    try {
      pads = [
        for (final pad in web.window.navigator.getGamepads().toDart)
          if (pad != null && pad.connected) _read(pad),
      ];
    } on Object {
      // No Gamepad API, or the page may not use it.
      return;
    }
    final text = pads.toString();
    if (text == last) {
      return;
    }
    last = text;
    onReport({'pads': pads});
  });
}

/// The buttons of the standard layout, by their index.
const _buttons = {
  0: 'a',
  1: 'b',
  2: 'x',
  3: 'y',
  4: 'l1',
  5: 'r1',
  6: 'l2',
  7: 'r2',
  12: 'up',
  13: 'down',
  14: 'left',
  15: 'right',
};

Map<String, Object> _read(web.Gamepad pad) {
  final axes = [for (final axis in pad.axes.toDart) axis.toDartDouble];
  final buttons = pad.buttons.toDart;
  double axis(int i) => i < axes.length ? _round(axes[i]) : 0;
  return {
    'kind': 'gamepad',
    // The browser's sticks point down with positive y, GameController's up.
    'lx': axis(0),
    'ly': -axis(1),
    'rx': axis(2),
    'ry': -axis(3),
    for (final MapEntry(key: index, value: name) in _buttons.entries)
      name: index < buttons.length && buttons[index].pressed,
  };
}

/// Two decimals: the noise of a resting stick is no change.
double _round(double value) => (value * 100).roundToDouble() / 100;
