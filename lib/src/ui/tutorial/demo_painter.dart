import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:horizont/horizont.dart';

import '../../game/components/power_up.dart';
import '../../game/components/tank_painter.dart';
import '../../game/game_config.dart';
import '../theme.dart';
import '../widgets/touch_controls.dart';
import '../../tv/tv_input.dart';
import 'practice.dart';
import 'tutorial_steps.dart';
import '../../l10n/l10n.dart';

/// Acts out one tutorial step on a small training ground: the tank drives,
/// aims and fires while a thumb works the sticks, or keys light up and the
/// mouse moves. [clock] runs from 0 to 1 and starts over, one pass of the
/// little scene.
///
/// Once the player takes over, [practice] is painted instead: their own
/// tank on the training ground.
///
/// Angles are the game's: 0 points up, positive turns clockwise.
class DemoPainter extends CustomPainter {
  DemoPainter({
    required this.scene,
    required this.touch,
    required this.clock,
    required this.top,
    this.pad,
    this.practice,
    this.invite = false,
    this.insets = EdgeInsets.zero,
  }) : super(repaint: Listenable.merge([clock, practice]));

  final DemoScene scene;
  final bool touch;

  /// On the Apple TV: the controller or the remote whose buttons to show,
  /// instead of keys or thumbs.
  final TvPadKind? pad;

  bool get _gamepad => pad == TvPadKind.gamepad;
  final Animation<double> clock;

  /// Where the card above the stage ends: the scene plays below it.
  final double top;

  /// The player's own tank, once they took over.
  final TutorialPractice? practice;

  /// Whether to invite the player to take over.
  final bool invite;

  /// The screen's safe-area insets, which the game's touch controls keep
  /// clear of: the sticks and buttons are drawn where the game puts them.
  final EdgeInsets insets;

  static const _hull = Color(0xFF6B7F3A);

  /// The ground of the drawn HUD plates over the training ground: sunken,
  /// a little see-through, like the game's plates over a round.
  static final _plate = GameColors.sunken.withValues(alpha: 0.7);
  static const _enemyHull = Color(0xFF8B3E2B);

  late Size _size;
  late double _t;

  double get _w => _size.width;
  double get _h => _size.height;

  /// Middle of the free space under the card.
  Offset get _center => Offset(_w / 2, top + (_h - top) * 0.42);
  double get _tankSize => (min(_w, _h - top) * 0.2).clamp(36.0, 72.0);
  // The sticks and buttons sit where `TouchControls` puts them in the game,
  // in the same size: what the card shows is what the thumb finds once the
  // player takes over, and in the round after.

  /// The room of the touch controls: the safe area with their margin.
  Rect get _controls => Rect.fromLTRB(
    max(insets.left, 10),
    max(insets.top, 8),
    _w - max(insets.right, 10),
    _h - max(insets.bottom, 8),
  );

  double get _stickRadius =>
      (min(_controls.width, _controls.height) * 0.36).clamp(112.0, 160.0) / 2;
  Offset get _leftStick => Offset(
    _controls.left + _stickRadius + 6,
    _controls.bottom - _stickRadius - 6,
  );
  Offset get _rightStick => Offset(
    _controls.right - _stickRadius - 6,
    _controls.bottom - _stickRadius - 6,
  );

  /// The upper edge of the buttons above the aim stick.
  double get _buttonTop {
    final area = _controls;
    final upright = area.height > area.width;
    final zoneTop = area.height * (upright ? 0.4 : 0.3);
    return area.top + max(zoneTop, area.height - 2 * _stickRadius - 104);
  }

  /// The round button of a special weapon, at the right edge.
  static const _specialSize = 68.0;
  Offset get _specialButton => Offset(
    _controls.right - 8 - _specialSize / 2,
    _buttonTop + _specialSize / 2,
  );

  /// The aim assist's pill, right-aligned above the aim stick and level
  /// with the lower edge of the special weapon's button.
  static const _assistHeight = 44.0;
  Rect _assistRect(double width) => Rect.fromLTRB(
    _controls.right - 8 - width,
    _buttonTop + _specialSize - _assistHeight,
    _controls.right - 8,
    _buttonTop + _specialSize,
  );

  /// Bottom left, where the keys are drawn on a desktop.
  Offset get _keys => Offset(24, _h - 120);

  /// The inventory slot at the left edge.
  Offset get _slot => Offset(34, top + (_h - top) * 0.3);

  @override
  void paint(Canvas canvas, Size size) {
    _size = size;
    _t = clock.value;
    _ground(canvas);
    if (practice case final practice?) {
      _practice(canvas, practice);
      return;
    }
    switch (scene) {
      case DemoScene.drive:
        _drive(canvas);
      case DemoScene.aim:
        _aim(canvas);
      case DemoScene.fire:
        _fire(canvas);
      case DemoScene.assist:
        _assist(canvas);
      case DemoScene.inventory:
        _inventory(canvas);
      case DemoScene.special:
        _special(canvas);
      case DemoScene.defense:
        _defense(canvas);
      case DemoScene.vehicles:
        _vehicles(canvas);
      case DemoScene.ready:
        _ready(canvas);
      case DemoScene.tour:
        break;
    }
    if (invite) {
      _pill(
        canvas,
        Offset(_w / 2, _h - 22),
        pad == TvPadKind.remote
            ? tr(
                'PROBIER ES SELBST: DAUMEN AUF DIE FERNBEDIENUNG',
                'TRY IT YOURSELF: THUMB ON THE REMOTE',
              )
            : pad == TvPadKind.gamepad
            ? tr(
                'PROBIER ES SELBST: STICKS DES CONTROLLERS',
                'TRY IT YOURSELF: THE CONTROLLER STICKS',
              )
            : touch
            ? tr(
                'PROBIER ES SELBST: DAUMEN AUF DIE STICKS',
                'TRY IT YOURSELF: THUMBS ON THE STICKS',
              )
            : tr(
                'PROBIER ES SELBST: W A S D UND MAUS',
                'TRY IT YOURSELF: W A S D AND MOUSE',
              ),
        color: GameColors.accentText,
      );
    }
  }

  @override
  bool shouldRepaint(DemoPainter old) =>
      old.scene != scene ||
      old.touch != touch ||
      old.pad != pad ||
      old.top != top ||
      old.practice != practice ||
      old.invite != invite ||
      old.insets != insets;

  // -------------------------------------------------------------- practice

  /// The player's own tank among the targets, with the keys they hold lit.
  void _practice(Canvas canvas, TutorialPractice p) {
    final size = p.tankSize;
    final mark = Paint();
    final markRect = Rect.fromCenter(
      center: Offset.zero,
      width: size * 0.13,
      height: size * 0.1,
    );
    for (final (i, (at, angle)) in p.trail.indexed) {
      final side = Offset(cos(angle), sin(angle)) * (size * 0.27);
      mark.color = Color.fromRGBO(30, 24, 14, 0.38 * (i + 1) / p.trail.length);
      for (final c in [at - side, at + side]) {
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(angle);
        canvas.drawRect(markRect, mark);
        canvas.restore();
      }
    }
    for (final target in p.targets.where((t) => t.standing)) {
      _tank(
        canvas,
        target.at,
        pi / 2,
        _angleOf(p.pos - target.at),
        hull: _enemyHull,
        type: TankType.keiler,
      );
    }
    for (final lob in p.lobs) {
      final ground = Offset.lerp(lob.from, lob.to, lob.t)!;
      final lift = sin(pi * lob.t) * size * 1.6;
      canvas.drawCircle(ground, 4, Paint()..color = const Color(0x55000000));
      canvas.drawCircle(
        ground - Offset(0, lift),
        5 + 3 * sin(pi * lob.t),
        Paint()..color = PowerUpType.grenades.color,
      );
    }
    _tank(canvas, p.pos, p.heading, p.turret, flash: p.flash);
    for (final shell in p.shells) {
      canvas.drawLine(
        shell.at - shell.dir * 18,
        shell.at,
        Paint()
          ..color = const Color(0x88FFE082)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        shell.at,
        3.5,
        Paint()..color = const Color(0xFFFFF3C4),
      );
    }
    for (final blast in p.blasts) {
      _blast(canvas, blast.at, blast.t, big: blast.big);
    }
    if (p.mouse case final mouse?) {
      _crosshair(canvas, mouse);
    }
    if (p.ring case final ring?) {
      canvas.drawCircle(
        ring,
        p.ringRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = GameColors.accentText,
      );
      canvas.drawCircle(
        ring,
        p.ringRadius,
        Paint()..color = GameColors.accentText.withValues(alpha: 0.15),
      );
    }
    _pill(
      canvas,
      Offset(_w / 2, top + 10),
      [
        if (p.done)
          tr('GESCHAFFT ✓', 'DONE ✓')
        else if (p.goal == PracticeGoal.reach)
          tr('AUFGABE: IN DEN KREIS FAHREN', 'TASK: DRIVE INTO THE RING')
        else
          tr(
            'AUFGABE: ${TutorialPractice.hitsNeeded} TREFFER '
                '(${p.hits}/${TutorialPractice.hitsNeeded})',
            'TASK: ${TutorialPractice.hitsNeeded} HITS '
                '(${p.hits}/${TutorialPractice.hitsNeeded})',
          ),
        if (p.grenades && !touch)
          tr('GRANATEN ${p.charges} (F)', 'GRENADES ${p.charges} (F)'),
      ].join('  ·  '),
      // Done is a status: word, tick and the positive colour.
      color: p.done ? GameColors.positive : GameColors.text,
    );
    if (!touch) {
      bool held(LogicalKeyboardKey a, [LogicalKeyboardKey? b]) =>
          p.keys.contains(a) || (b != null && p.keys.contains(b));
      _key(
        canvas,
        _keys + const Offset(40, 0),
        'W',
        lit: held(LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp),
      );
      _key(
        canvas,
        _keys + const Offset(0, 40),
        'A',
        lit: held(LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft),
      );
      _key(
        canvas,
        _keys + const Offset(40, 40),
        'S',
        lit: held(LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown),
      );
      _key(
        canvas,
        _keys + const Offset(80, 40),
        'D',
        lit: held(LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight),
      );
      _caption(
        canvas,
        _keys + const Offset(0, 84),
        tr(
          'MAUS ZIELT · KLICK ODER LEERTASTE FEUERT',
          'MOUSE AIMS · CLICK OR SPACE FIRES',
        ),
      );
    }
  }

  // ---------------------------------------------------------------- scenes

  /// A figure eight: the thumb points along the path, or W stays down while
  /// A and D follow the bends.
  void _drive(Canvas canvas) {
    final rx = min(_w * 0.24, 260.0);
    final ry = min((_h - top) * 0.2, 90.0);
    (Offset, Offset) at(double t) {
      final phi = 2 * pi * t;
      return (
        _center + Offset(rx * sin(phi), ry * sin(2 * phi)),
        Offset(rx * cos(phi), 2 * ry * cos(2 * phi)),
      );
    }

    // Two rows of track marks under the chains, placed and fading like the
    // game's (TankBase._leaveTrail), not a single trail down the middle.
    final mark = Paint();
    final markRect = Rect.fromCenter(
      center: Offset.zero,
      width: _tankSize * 0.13,
      height: _tankSize * 0.1,
    );
    const marks = 60;
    for (var i = 1; i < marks; i++) {
      final (p, v) = at(_t - i * 0.006);
      final angle = _angleOf(v);
      final side = Offset(cos(angle), sin(angle)) * (_tankSize * 0.27);
      final back = Offset(sin(angle), -cos(angle)) * (_tankSize * 0.1);
      mark.color = Color.fromRGBO(30, 24, 14, 0.38 * (1 - i / marks));
      for (final c in [p - side - back, p + side - back]) {
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(angle);
        canvas.drawRect(markRect, mark);
        canvas.restore();
      }
    }
    final (pos, vel) = at(_t);
    final heading = _angleOf(vel);
    _tank(canvas, pos, heading, heading);
    if (pad != null) {
      final dir = vel / vel.distance;
      _stick(
        canvas,
        _leftStick,
        _leftStick + dir * _stickRadius * 0.75,
        _gamepad
            ? tr('LINKER STICK · FAHREN', 'LEFT STICK · DRIVE')
            : tr('TOUCHFLÄCHE · FAHREN', 'TOUCH SURFACE · DRIVE'),
      );
    } else if (touch) {
      final dir = vel / vel.distance;
      final knob = _leftStick + dir * _stickRadius * 0.75;
      _stick(canvas, _leftStick, knob, tr('FAHREN', 'DRIVE'));
      _stick(
        canvas,
        _rightStick,
        null,
        tr('ZIELEN · FEUER', 'AIM · FIRE'),
        ring: true,
      );
      _finger(canvas, knob, fromLeft: true);
    } else {
      // Bend of the path: positive turns right.
      final (_, next) = at(_t + 0.01);
      var turn = _angleOf(next) - heading;
      turn = atan2(sin(turn), cos(turn));
      _wasd(canvas, w: true, a: turn < -0.03, d: turn > 0.03);
    }
  }

  /// The tank stands, the turret sweeps after the right thumb or the mouse.
  void _aim(Canvas canvas) {
    final pos = _center;
    final aim = 1.15 * sin(2 * pi * _t);
    final dir = _dir(aim);
    // Not up into the card.
    final reach = min(_tankSize * 3.2, pos.dy - top - 24);
    _dashes(canvas, pos + dir * _tankSize * 0.7, pos + dir * reach);
    _tank(canvas, pos, 0, aim);
    if (_gamepad) {
      _stick(
        canvas,
        _rightStick,
        _rightStick + dir * _stickRadius * 0.45,
        tr('RECHTER STICK · ZIELEN', 'RIGHT STICK · AIM'),
      );
    } else if (pad != null) {
      _crosshair(canvas, pos + dir * reach);
      _caption(
        canvas,
        _keys + const Offset(0, 84),
        tr('DIE ZIELHILFE ZIELT', 'THE AIM ASSIST AIMS'),
      );
    } else if (touch) {
      final knob = _rightStick + dir * _stickRadius * 0.45;
      _stick(canvas, _leftStick, null, tr('FAHREN', 'DRIVE'));
      _stick(
        canvas,
        _rightStick,
        knob,
        tr('ZIELEN · FEUER', 'AIM · FIRE'),
        ring: true,
      );
      _finger(canvas, knob, fromLeft: false);
    } else {
      _crosshair(canvas, pos + dir * reach);
      _key(canvas, _keys + const Offset(0, 40), 'Q');
      _key(canvas, _keys + const Offset(40, 40), 'E');
      _caption(
        canvas,
        _keys + const Offset(0, 84),
        tr('ODER TURM PER TASTE', 'OR TURRET BY KEY'),
      );
    }
  }

  /// Two shots onto an enemy tank.
  void _fire(Canvas canvas) {
    final pos = Offset(_w * 0.3, _center.dy + _tankSize * 0.4);
    final enemy = Offset(_w * 0.7, _center.dy - _tankSize * 0.4);
    final target = _angleOf(enemy - pos);
    final settle = _ease(_seg(0, 0.25));
    final aim = target * settle;
    const shots = [0.35, 0.55];
    _duel(canvas, pos, enemy, aim, shots);
    if (pad != null) {
      _key(
        canvas,
        _keys + const Offset(0, 40),
        _gamepad ? 'R2' : tr('KLICK', 'CLICK'),
        width: _gamepad ? null : 76,
        lit: _pulse(shots),
      );
      _caption(
        canvas,
        _keys + const Offset(0, 84),
        _gamepad
            ? tr('ODER A', 'OR A')
            : tr('AUF DIE TOUCHFLÄCHE', 'ON THE TOUCH SURFACE'),
      );
    } else if (touch) {
      // Out to the ring to aim, past it to fire, back to rest.
      final reach = _t < 0.25
          ? 0.45 * settle
          : _t < 0.32
          ? 0.45 + 0.45 * _ease(_seg(0.25, 0.32))
          : _t < 0.7
          ? 0.9
          : 0.9 * (1 - _ease(_seg(0.7, 0.8)));
      final knob = _rightStick + _dir(aim) * _stickRadius * reach;
      _stick(canvas, _leftStick, null, tr('FAHREN', 'DRIVE'));
      _stick(
        canvas,
        _rightStick,
        knob,
        tr('ZIELEN · FEUER', 'AIM · FIRE'),
        ring: true,
        firing: reach > TouchControls.fireRing,
      );
      if (_t < 0.85) {
        _finger(canvas, knob, fromLeft: false);
      }
    } else {
      final cursor = Offset.lerp(
        Offset(_w * 0.55, _center.dy + _tankSize * 1.2),
        enemy,
        settle,
      )!;
      _crosshair(canvas, cursor, clicks: shots);
      _spaceBar(canvas, _keys + const Offset(0, 40), lit: _pulse(shots));
      _caption(
        canvas,
        _keys + const Offset(0, 84),
        tr('ODER LINKSKLICK', 'OR LEFT CLICK'),
      );
    }
  }

  /// A tap on the assist button, then the turret finds the enemy by itself.
  void _assist(Canvas canvas) {
    final pos = Offset(_w * 0.32, _center.dy);
    // It weaves up and down, but stays clear of the buttons above the aim
    // stick on a short stage.
    final swing = min(
      (_h - top) * 0.18,
      max(0.0, _buttonTop - 12 - _tankSize * 0.75 - _center.dy),
    );
    Offset enemyAt(double t) =>
        Offset(_w * 0.68, _center.dy + swing * sin(2 * pi * t));
    final enemy = enemyAt(_t);
    final on = _t > 0.12;
    final aim = on ? _angleOf(enemy - pos) : 0.0;
    const shots = [0.35, 0.6, 0.85];
    _duel(canvas, pos, enemy, aim, shots, moving: enemyAt);
    if (on) {
      _lock(canvas, enemy);
    }
    _stick(canvas, _leftStick, null, tr('FAHREN', 'DRIVE'));
    _stick(
      canvas,
      _rightStick,
      null,
      tr('ZIELEN · FEUER', 'AIM · FIRE'),
      ring: true,
    );
    final toggle = _assistToggle(canvas, on: on);
    if (_t < 0.2) {
      _finger(canvas, toggle.center, fromLeft: false, press: _seg(0.06, 0.12));
    }
  }

  /// Over a crate, into the inventory, and set off with a tap or key 1.
  void _inventory(Canvas canvas) {
    final start = Offset(_w * 0.3, _center.dy);
    final stop = Offset(_w * 0.62, _center.dy);
    final crate = Offset(_w * 0.56, _center.dy);
    final pos = Offset.lerp(start, stop, _ease(_seg(0, 0.35)))!;
    const type = PowerUpType.shield;
    final picked = _t > 0.31;
    final used = _t > 0.68;
    if (!picked) {
      _crate(canvas, crate, type);
    }
    _tank(canvas, pos, pi / 2, pi / 2);
    if (used) {
      final glow = 0.6 + 0.4 * sin(_t * 40);
      canvas.drawCircle(
        pos,
        _tankSize * 0.85,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = type.color.withValues(alpha: glow),
      );
      canvas.drawCircle(
        pos,
        _tankSize * 0.85,
        Paint()..color = type.color.withValues(alpha: 0.15),
      );
    }
    // The crate's symbol flies to the left edge.
    if (picked && _t < 0.5) {
      final p = _ease(_seg(0.31, 0.5));
      _icon(canvas, Offset.lerp(crate, _slot, p)!, type.icon, 22, type.color);
    }
    _inventorySlot(canvas, _t >= 0.5 && !used ? type : null);
    if (pad != null) {
      _key(
        canvas,
        _keys + const Offset(0, 40),
        _gamepad ? 'X' : 'PLAY/PAUSE',
        width: _gamepad ? null : 120,
        lit: _between(0.62, 0.7),
      );
      _caption(
        canvas,
        _keys + const Offset(0, 84),
        _gamepad
            ? tr('X, Y UND STEUERKREUZ', 'X, Y AND D-PAD')
            : tr('OBERSTES FELD', 'TOP SLOT'),
      );
    } else if (touch) {
      if (_t > 0.5 && _t < 0.8) {
        final reach = _ease(_seg(0.5, 0.62));
        final finger = Offset.lerp(
          Offset(_slot.dx + 90, _slot.dy + 90),
          _slot,
          reach,
        )!;
        _finger(canvas, finger, fromLeft: true, press: _seg(0.62, 0.68));
      }
    } else {
      _key(canvas, _keys + const Offset(0, 40), '1', lit: _between(0.62, 0.7));
      _caption(
        canvas,
        _keys + const Offset(0, 84),
        tr('TASTEN 1 BIS 6', 'KEYS 1 TO 6'),
      );
    }
  }

  /// A grenade over a wall onto an enemy behind it.
  void _special(Canvas canvas) {
    final pos = Offset(_w * 0.3, _center.dy + _tankSize * 0.3);
    final enemy = Offset(_w * 0.72, _center.dy - _tankSize * 0.2);
    final wall = Offset(_w * 0.53, _center.dy);
    const weapon = PowerUpType.grenades;
    const shots = [0.3, 0.62];
    final aim = _angleOf(enemy - pos);
    var hit = 0.0;
    for (final shot in shots) {
      final e = _seg(shot + 0.25, shot + 0.45);
      if (e > 0 && e < 1) {
        hit = 1 - e;
      }
    }
    _tank(
      canvas,
      enemy + Offset(sin(_t * 90) * 2 * hit, 0),
      -pi / 2,
      -pi / 2 - 0.3,
      hull: _enemyHull,
      type: TankType.keiler,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: wall,
        width: _tankSize * 0.35,
        height: _tankSize * 1.6,
      ),
      Paint()..color = const Color(0xFF8D7B62),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: wall,
        width: _tankSize * 0.35,
        height: _tankSize * 1.6,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF4E4337),
    );
    _tank(canvas, pos, 0, aim, flash: _flash(shots));
    for (final shot in shots) {
      final p = _seg(shot, shot + 0.25);
      if (p > 0 && p < 1) {
        final ground = Offset.lerp(pos, enemy, p)!;
        final lift = sin(pi * p) * (_h - top) * 0.3;
        canvas.drawCircle(ground, 4, Paint()..color = const Color(0x55000000));
        canvas.drawCircle(
          ground - Offset(0, lift),
          5 + 3 * sin(pi * p),
          Paint()..color = weapon.color,
        );
      }
      _blast(canvas, enemy, _seg(shot + 0.25, shot + 0.45), big: true);
    }
    final left = 3 - shots.where((s) => _t > s).length;
    if (pad != null) {
      _crosshair(canvas, enemy);
      _key(
        canvas,
        _keys + const Offset(0, 40),
        _gamepad ? 'L2' : 'PLAY/PAUSE',
        width: _gamepad ? null : 120,
        lit: _pulse(shots),
      );
      _caption(
        canvas,
        _keys + const Offset(0, 84),
        tr('GRANATWERFER  $left', 'GRENADE LAUNCHER  $left'),
      );
    } else if (touch) {
      _stick(canvas, _leftStick, null, tr('FAHREN', 'DRIVE'));
      _stick(
        canvas,
        _rightStick,
        null,
        tr('ZIELEN · FEUER', 'AIM · FIRE'),
        ring: true,
      );
      _specialButtonOf(
        canvas,
        weapon.color,
        tr('GRANATE', 'GRENADE'),
        left,
        lit: _pulse(shots, width: 0.06),
      );
      final pressing = shots.any((s) => _t > s - 0.08 && _t < s + 0.08);
      if (pressing) {
        final s = shots.firstWhere((s) => _t > s - 0.08 && _t < s + 0.08);
        _finger(
          canvas,
          _specialButton,
          fromLeft: false,
          press: _seg(s - 0.04, s),
        );
      }
    } else {
      _crosshair(canvas, enemy);
      _key(canvas, _keys + const Offset(0, 40), 'F', lit: _pulse(shots));
      _caption(
        canvas,
        _keys + const Offset(0, 84),
        tr('GRANATWERFER  $left', 'GRENADE LAUNCHER  $left'),
      );
    }
  }

  /// A gun goes up next to the tank and holds the road.
  void _defense(Canvas canvas) {
    final road = Paint()
      ..color = const Color(0x995A4A32)
      ..strokeWidth = _tankSize * 1.2
      ..strokeCap = StrokeCap.butt;
    // Road near the card, tank and gun beside it, the build bar at the
    // bottom.
    final roadY = top + (_h - top) * 0.22;
    canvas.drawLine(Offset(0, roadY), Offset(_w, roadY), road);
    // The base on the left.
    final base = Rect.fromCenter(
      center: Offset(_w * 0.1, roadY),
      width: _tankSize * 1.3,
      height: _tankSize * 1.3,
    );
    canvas.drawRect(base, Paint()..color = const Color(0xFF4E5A34));
    canvas.drawRect(
      base,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = GameColors.text,
    );
    _icon(
      canvas,
      base.center,
      Icons.fort_outlined,
      _tankSize * 0.6,
      GameColors.text,
    );

    final pos = Offset(_w * 0.34, roadY + _tankSize * 1.1);
    final gun = Offset(_w * 0.5, roadY + _tankSize * 0.9);
    final built = _t > 0.22;
    // The remote builds, but has no button to switch the kind.
    final flak = !touch && pad != TvPadKind.remote && _t > 0.52;
    // The enemy rolls in from the right and is stopped.
    final enemyX = _w + _tankSize - (_w * 0.38) * _ease(_seg(0.1, 0.55));
    final enemy = Offset(enemyX, roadY);
    const shots = [0.45, 0.7];
    _tank(canvas, pos, 0, _angleOf(enemy - pos));
    _tank(
      canvas,
      enemy,
      -pi / 2,
      -pi / 2,
      hull: _enemyHull,
      type: TankType.keiler,
    );
    if (built) {
      final grow = _ease(_seg(0.22, 0.3));
      _gun(canvas, gun, _angleOf(enemy - gun), grow, _flash(shots));
      for (final shot in shots) {
        _shell(canvas, gun, enemy, _seg(shot, shot + 0.12));
        _blast(canvas, enemy, _seg(shot + 0.12, shot + 0.3));
      }
    }
    final money = built ? 50 : 150;
    // The build bar: what can be built and what it costs.
    final kinds = [(tr('KANONE', 'CANNON'), 100), ('FLAK', 120)];
    final barLeft = touch ? _w / 2 - 110 : _keys.dx + (pad == null ? 140 : 160);
    final barTop = _h - 64.0;
    _caption(
      canvas,
      Offset(barLeft + kinds.length * 112 + 6, barTop + 11),
      tr('MÜNZEN $money', 'COINS $money'),
    );
    for (final (i, (label, cost)) in kinds.indexed) {
      final chosen = flak ? i == 1 : i == 0;
      final rect = Rect.fromLTWH(barLeft + i * 112, barTop, 104, 34);
      _button(canvas, rect, '$label $cost', filled: chosen);
    }
    if (_gamepad) {
      _key(
        canvas,
        _keys + const Offset(0, 40),
        'R1',
        lit: _between(0.16, 0.24),
      );
      _key(
        canvas,
        _keys + const Offset(40, 40),
        'L1',
        lit: _between(0.52, 0.6),
      );
      _caption(
        canvas,
        _keys + const Offset(0, 84),
        tr('BAUEN · TYP', 'BUILD · TYPE'),
      );
    } else if (pad != null) {
      _key(
        canvas,
        _keys + const Offset(0, 40),
        'PLAY/PAUSE',
        width: 120,
        lit: _between(0.16, 0.24),
      );
      _caption(canvas, _keys + const Offset(0, 84), tr('BAUEN', 'BUILD'));
    } else if (touch) {
      final button = Offset(barLeft + 52, barTop + 17);
      if (_t < 0.35) {
        final reach = _ease(_seg(0.02, 0.16));
        _finger(
          canvas,
          Offset.lerp(button + const Offset(60, 70), button, reach)!,
          fromLeft: false,
          press: _seg(0.16, 0.22),
        );
      }
    } else {
      _key(canvas, _keys + const Offset(0, 40), 'B', lit: _between(0.16, 0.24));
      _key(canvas, _keys + const Offset(40, 40), 'V', lit: _between(0.52, 0.6));
      _caption(
        canvas,
        _keys + const Offset(0, 84),
        tr('BAUEN · TYP', 'BUILD · TYPE'),
      );
    }
  }

  /// All vehicles in a row, each turret swinging a little.
  void _vehicles(Canvas canvas) {
    const types = TankType.values;
    final cell = min(_w / (types.length + 1), 110.0);
    final size = (cell * 0.6).clamp(28.0, 60.0);
    final y = top + (_h - top) * 0.5;
    final left = (_w - cell * types.length) / 2 + cell / 2;
    for (final (i, type) in types.indexed) {
      final appear = _ease(_seg(i * 0.06, i * 0.06 + 0.15));
      if (appear <= 0) {
        continue;
      }
      final at = Offset(left + i * cell, y + (1 - appear) * 30);
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.scale(appear);
      canvas.translate(-size / 2, -size / 2);
      paintTank(
        canvas,
        size,
        type,
        GameConfig.tankColors[i % GameConfig.freeColors],
        turretAngle: 0.4 * sin(2 * pi * _t + i),
      );
      canvas.restore();
      _text(
        canvas,
        at + Offset(0, size * 0.75),
        type.label,
        size: 10,
        color: GameColors.text,
        center: true,
        maxWidth: cell - 4,
      );
      _text(
        canvas,
        at + Offset(0, size * 0.75 + 14),
        type.level == 1
            ? tr('AB START', 'FROM START')
            : tr('AB STUFE ${type.level}', 'FROM LEVEL ${type.level}'),
        size: 9,
        color: GameColors.textMuted,
        center: true,
        maxWidth: cell - 4,
      );
    }
  }

  /// The tank rolls past, turret on the viewer.
  void _ready(Canvas canvas) {
    final pos = Offset(
      _w * 0.2 + _w * 0.6 * _t,
      _center.dy + sin(_t * pi * 4) * 4,
    );
    final mark = Paint()..color = const Color(0x33000000);
    for (var x = _w * 0.2; x < pos.dx; x += 7) {
      canvas.drawCircle(Offset(x, _center.dy), _tankSize * 0.08, mark);
    }
    _tank(canvas, pos, pi / 2, pi);
  }

  // ------------------------------------------------------------- the field

  void _ground(Canvas canvas) {
    canvas.drawRect(
      Offset.zero & _size,
      Paint()..color = const Color(0xFF2C3620),
    );
    // Patches of grass and earth, the same every frame.
    final random = Random(7);
    for (var i = 0; i < 40; i++) {
      final p = Offset(random.nextDouble() * _w, random.nextDouble() * _h);
      canvas.drawOval(
        Rect.fromCenter(
          center: p,
          width: 40 + random.nextDouble() * 120,
          height: 20 + random.nextDouble() * 70,
        ),
        Paint()
          ..color =
              (i.isEven ? const Color(0xFF34401F) : const Color(0xFF3A3524))
                  .withValues(alpha: 0.6),
      );
    }
    final grid = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1;
    for (var x = 0.0; x < _w; x += 64) {
      canvas.drawLine(Offset(x, 0), Offset(x, _h), grid);
    }
    for (var y = 0.0; y < _h; y += 64) {
      canvas.drawLine(Offset(0, y), Offset(_w, y), grid);
    }
  }

  void _tank(
    Canvas canvas,
    Offset at,
    double heading,
    double turret, {
    Color hull = _hull,
    TankType type = TankType.hermelin,
    double flash = 0,
  }) {
    final size = _tankSize;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(heading);
    canvas.translate(-size / 2, -size / 2);
    paintTank(
      canvas,
      size,
      type,
      hull,
      turretAngle: turret - heading,
      flash: flash,
      recoil: flash,
    );
    canvas.restore();
  }

  /// Our tank fires [shots] at an enemy, which flinches at every hit.
  void _duel(
    Canvas canvas,
    Offset pos,
    Offset enemy,
    double aim,
    List<double> shots, {
    Offset Function(double t)? moving,
  }) {
    var hit = 0.0;
    for (final shot in shots) {
      final e = _seg(shot + 0.12, shot + 0.3);
      if (e > 0 && e < 1) {
        hit = 1 - e;
      }
    }
    _tank(
      canvas,
      enemy + Offset(sin(_t * 90) * 3 * hit, 0),
      -pi / 2,
      _angleOf(pos - enemy),
      hull: _enemyHull,
      type: TankType.keiler,
    );
    _tank(canvas, pos, 0, aim, flash: _flash(shots));
    for (final shot in shots) {
      final target = moving?.call(shot + 0.12) ?? enemy;
      _shell(canvas, pos, target, _seg(shot, shot + 0.12));
      _blast(canvas, target, _seg(shot + 0.12, shot + 0.3));
    }
  }

  void _shell(Canvas canvas, Offset from, Offset to, double p) {
    if (p <= 0 || p >= 1) {
      return;
    }
    final dir = (to - from) / (to - from).distance;
    final start = from + dir * _tankSize * 0.6;
    final at = Offset.lerp(start, to, p)!;
    canvas.drawLine(
      at - dir * 18,
      at,
      Paint()
        ..color = const Color(0x88FFE082)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(at, 3.5, Paint()..color = const Color(0xFFFFF3C4));
  }

  void _blast(Canvas canvas, Offset at, double p, {bool big = false}) {
    if (p <= 0 || p >= 1) {
      return;
    }
    final reach = _tankSize * (big ? 0.9 : 0.6);
    canvas.drawCircle(
      at,
      reach * (0.3 + 0.7 * p),
      Paint()..color = const Color(0xFFFF7043).withValues(alpha: 1 - p),
    );
    canvas.drawCircle(
      at,
      reach * 0.5 * (0.3 + 0.7 * p),
      Paint()..color = const Color(0xFFFFE082).withValues(alpha: 1 - p),
    );
  }

  void _gun(Canvas canvas, Offset at, double aim, double grow, double flash) {
    final r = _tankSize * 0.32 * grow;
    if (r <= 0) {
      return;
    }
    canvas.drawRect(
      Rect.fromCenter(center: at, width: r * 2.6, height: r * 2.6),
      Paint()..color = const Color(0xFF5A5340),
    );
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(aim);
    canvas.drawRect(
      Rect.fromLTWH(-r * 0.18, -r * 2.1, r * 0.36, r * 2.1),
      Paint()..color = const Color(0xFF262626),
    );
    if (flash > 0) {
      canvas.drawCircle(
        Offset(0, -r * 2.2),
        r * 0.6 * flash,
        Paint()..color = const Color(0xFFFFE082),
      );
    }
    canvas.restore();
    canvas.drawCircle(at, r, Paint()..color = GameColors.accent);
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = GameColors.text,
    );
  }

  void _crate(Canvas canvas, Offset at, PowerUpType type) {
    final bob = sin(_t * 2 * pi * 2) * 2;
    final rect = Rect.fromCenter(
      center: at + Offset(0, bob),
      width: _tankSize * 0.5,
      height: _tankSize * 0.5,
    );
    canvas.drawRect(rect, Paint()..color = const Color(0xFF6D5A3A));
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = type.color,
    );
    _icon(canvas, rect.center, type.icon, rect.width * 0.65, type.color);
  }

  void _inventorySlot(Canvas canvas, PowerUpType? held) {
    final rect = Rect.fromCenter(center: _slot, width: 48, height: 48);
    final slot = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(HzRadius.r6),
    );
    canvas.drawRRect(slot, Paint()..color = _plate);
    canvas.drawRRect(
      slot,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = held == null ? HzLine.hairline : HzLine.selection
        ..color = held == null ? GameColors.lineStrong : held.color,
    );
    if (held != null) {
      _icon(canvas, rect.center, held.icon, 26, held.color);
    }
    if (!touch && pad != TvPadKind.remote) {
      _text(
        canvas,
        rect.topLeft + const Offset(4, 2),
        _gamepad ? 'X' : '1',
        size: 10,
        color: GameColors.textMuted,
        mono: true,
      );
    }
    _text(
      canvas,
      rect.bottomCenter + const Offset(0, 4),
      tr('INVENTAR', 'INVENTORY'),
      size: 9,
      color: GameColors.textMuted,
      center: true,
    );
  }

  // ------------------------------------------------------- touch gestures

  void _stick(
    Canvas canvas,
    Offset base,
    Offset? knob,
    String label, {
    bool ring = false,
    bool firing = false,
  }) {
    final r = _stickRadius;
    final idle = knob == null;
    canvas.drawCircle(
      base,
      r,
      Paint()..color = GameColors.sunken.withValues(alpha: idle ? 0.15 : 0.3),
    );
    canvas.drawCircle(
      base,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = GameColors.text.withValues(alpha: idle ? 0.2 : 0.55),
    );
    if (ring) {
      canvas.drawCircle(
        base,
        r * TouchControls.fireRing,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = firing ? 3 : 1.5
          ..color = (firing ? GameColors.critical : GameColors.accentText)
              .withValues(alpha: idle ? 0.3 : 0.8),
      );
    }
    if (knob != null) {
      canvas.drawLine(
        base,
        knob,
        Paint()
          ..color = GameColors.text.withValues(alpha: 0.35)
          ..strokeWidth = 4,
      );
      canvas.drawCircle(
        knob,
        r * 0.38,
        Paint()..color = (firing ? GameColors.critical : GameColors.text),
      );
    }
    // Above the ring on a dark plate like the game's sticks, readable on any
    // ground and kept on screen.
    _pill(canvas, base - Offset(0, r + 16), label);
  }

  /// [text] on a dark plate centred on [at], shifted back inside the stage:
  /// sunken, a little see-through, with the one outline.
  void _pill(
    Canvas canvas,
    Offset at,
    String text, {
    Color color = GameColors.text,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontFamily: HzFont.sans,
          package: HzFont.package,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = painter.width + 16;
    final height = painter.height + 6;
    final left = (at.dx - width / 2)
        .clamp(8.0, max(8.0, _w - 8 - width))
        .toDouble();
    final rect = Rect.fromLTWH(left, at.dy - height / 2, width, height);
    final plate = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(HzRadius.r6),
    );
    canvas.drawRRect(plate, Paint()..color = _plate);
    canvas.drawRRect(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = HzLine.hairline
        ..color = GameColors.lineStrong,
    );
    painter.paint(canvas, rect.topLeft + const Offset(8, 3));
    painter.dispose();
  }

  /// A thumb seen from above: the tip on [at], the rest reaching to the
  /// lower edge it comes from. [press] from 0 to 1 sends a ripple.
  void _finger(
    Canvas canvas,
    Offset at, {
    required bool fromLeft,
    double press = 0,
  }) {
    final down = Offset(fromLeft ? -0.45 : 0.45, 1);
    final dir = down / down.distance;
    final length = _stickRadius * 1.3;
    final body = Paint()
      ..color = const Color(0x66F5E6D3)
      ..strokeWidth = 34
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(at + dir * 8, at + dir * length, body);
    canvas.drawCircle(at, 17, Paint()..color = const Color(0xDDF5E6D3));
    canvas.drawCircle(
      at,
      17,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF8A7A66),
    );
    if (press > 0 && press < 1) {
      canvas.drawCircle(
        at,
        17 + 26 * press,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = GameColors.accentText.withValues(alpha: 1 - press),
      );
    }
  }

  /// The game's aim assist toggle: a dark plate, framed by the selection
  /// line in the accent when on and by the hairline when off, the crosshair
  /// and two lines. Returns where it lies.
  Rect _assistToggle(Canvas canvas, {required bool on}) {
    final color = on ? GameColors.accentText : GameColors.textMuted;
    TextPainter line(String text, double size, Color color, FontWeight w) =>
        TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontSize: size,
              color: color,
              fontFamily: HzFont.sans,
              package: HzFont.package,
              fontWeight: w,
              letterSpacing: size < 10 ? 0.3 : 0,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
    final title = line(
      on
          ? tr('ZIELHILFE AN', 'AIM ASSIST ON')
          : tr('ZIELHILFE AUS', 'AIM ASSIST OFF'),
      11,
      color,
      FontWeight.w600,
    );
    final hint = line(
      on
          ? tr('feuert selbst', 'fires by itself')
          : tr('du zielst selbst', 'you aim yourself'),
      9,
      GameColors.text,
      FontWeight.w400,
    );
    final width = 48.0 + max(title.width, hint.width);
    final rect = _assistRect(width);
    final plate = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(HzRadius.r6),
    );
    canvas.drawRRect(plate, Paint()..color = _plate);
    canvas.drawRRect(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = on ? HzLine.selection : HzLine.hairline
        ..color = on ? GameColors.accentText : GameColors.lineStrong,
    );
    _icon(
      canvas,
      Offset(rect.left + 12 + 9, rect.center.dy),
      Icons.gps_fixed_outlined,
      18,
      color,
    );
    final textLeft = rect.left + 12 + 18 + 6;
    final textTop = rect.center.dy - (title.height + hint.height) / 2;
    title.paint(canvas, Offset(textLeft, textTop));
    hint.paint(canvas, Offset(textLeft, textTop + title.height));
    title.dispose();
    hint.dispose();
    return rect;
  }

  /// The game's round button of a special weapon: the gem, its name and
  /// the charges left, in the weapon's colour.
  void _specialButtonOf(
    Canvas canvas,
    Color color,
    String name,
    int charges, {
    bool lit = false,
  }) {
    final at = _specialButton;
    const radius = _specialSize / 2;
    canvas.drawCircle(
      at,
      radius,
      Paint()..color = lit ? color.withValues(alpha: 0.6) : _plate,
    );
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color,
    );
    _icon(canvas, at + const Offset(0, -14), Icons.diamond_outlined, 18, color);
    _text(
      canvas,
      at + const Offset(0, -3),
      name,
      size: 10,
      color: GameColors.text,
      center: true,
    );
    _text(
      canvas,
      at + const Offset(0, 9),
      '×$charges',
      size: 11,
      color: GameColors.text,
      center: true,
      mono: true,
    );
  }

  // -------------------------------------------------------- keys and mouse

  void _wasd(Canvas canvas, {bool w = false, bool a = false, bool d = false}) {
    _key(canvas, _keys + const Offset(40, 0), 'W', lit: w);
    _key(canvas, _keys + const Offset(0, 40), 'A', lit: a);
    _key(canvas, _keys + const Offset(40, 40), 'S');
    _key(canvas, _keys + const Offset(80, 40), 'D', lit: d);
    _caption(
      canvas,
      _keys + const Offset(0, 84),
      tr('ODER PFEILTASTEN', 'OR ARROW KEYS'),
    );
  }

  void _key(
    Canvas canvas,
    Offset at,
    String label, {
    bool lit = false,
    double? width,
  }) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(at.dx, at.dy + (lit ? 2 : 0), width ?? 34, 34),
      const Radius.circular(HzRadius.r6),
    );
    if (!lit) {
      // The key's side, gone when it is pressed down.
      canvas.drawRRect(
        rect.shift(const Offset(0, 3)),
        Paint()..color = GameColors.sunken,
      );
    }
    canvas.drawRRect(
      rect,
      Paint()..color = lit ? GameColors.accent : GameColors.surface,
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = HzLine.hairline
        ..color = lit ? GameColors.accent : GameColors.lineStrong,
    );
    _text(
      canvas,
      rect.center - const Offset(0, 8),
      label,
      size: 14,
      color: lit ? GameColors.onAccent : GameColors.text,
      center: true,
      bold: true,
    );
  }

  void _spaceBar(Canvas canvas, Offset at, {bool lit = false}) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(at.dx, at.dy + (lit ? 2 : 0), 154, 34),
      const Radius.circular(HzRadius.r6),
    );
    if (!lit) {
      canvas.drawRRect(
        rect.shift(const Offset(0, 3)),
        Paint()..color = GameColors.sunken,
      );
    }
    canvas.drawRRect(
      rect,
      Paint()..color = lit ? GameColors.accent : GameColors.surface,
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = HzLine.hairline
        ..color = lit ? GameColors.accent : GameColors.lineStrong,
    );
    _text(
      canvas,
      rect.center - const Offset(0, 7),
      tr('LEERTASTE', 'SPACE'),
      size: 11,
      color: lit ? GameColors.onAccent : GameColors.text,
      center: true,
      bold: true,
    );
  }

  /// The game's precise cursor. A ring spreads at every time in [clicks].
  void _crosshair(Canvas canvas, Offset at, {List<double> clicks = const []}) {
    final line = Paint()
      ..color = GameColors.text
      ..strokeWidth = 2;
    canvas.drawCircle(
      at,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = GameColors.text,
    );
    for (final d in const [
      Offset(1, 0),
      Offset(-1, 0),
      Offset(0, 1),
      Offset(0, -1),
    ]) {
      canvas.drawLine(at + d * 6, at + d * 17, line);
    }
    for (final click in clicks) {
      final p = _seg(click, click + 0.08);
      if (p > 0 && p < 1) {
        canvas.drawCircle(
          at,
          12 + 22 * p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = GameColors.accentText.withValues(alpha: 1 - p),
        );
      }
    }
  }

  // ---------------------------------------------------------------- helpers

  void _lock(Canvas canvas, Offset at) {
    final r = _tankSize * 0.75;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = GameColors.accentText;
    for (final (sx, sy) in const [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
      final corner = at + Offset(sx * r, sy * r);
      canvas.drawLine(corner, corner - Offset(sx * r * 0.35, 0), paint);
      canvas.drawLine(corner, corner - Offset(0, sy * r * 0.35), paint);
    }
  }

  void _dashes(Canvas canvas, Offset from, Offset to) {
    final paint = Paint()
      ..color = GameColors.accentText.withValues(alpha: 0.4)
      ..strokeWidth = 2;
    final length = (to - from).distance;
    final dir = (to - from) / length;
    for (var d = 0.0; d < length; d += 14) {
      canvas.drawLine(from + dir * d, from + dir * min(d + 7, length), paint);
    }
  }

  /// A button of the game as Horizont draws it: the one primary action
  /// filled in the accent, every other on the plate with the hairline.
  void _button(Canvas canvas, Rect rect, String label, {bool filled = false}) {
    final shape = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(HzRadius.r6),
    );
    canvas.drawRRect(
      shape,
      Paint()..color = filled ? GameColors.accent : _plate,
    );
    if (!filled) {
      canvas.drawRRect(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = HzLine.hairline
          ..color = GameColors.lineStrong,
      );
    }
    _text(
      canvas,
      rect.center - const Offset(0, 7),
      label,
      size: 11,
      color: filled ? GameColors.onAccent : GameColors.text,
      center: true,
      bold: true,
    );
  }

  void _caption(Canvas canvas, Offset at, String text) =>
      _text(canvas, at, text, size: 10, color: GameColors.textMuted);

  void _text(
    Canvas canvas,
    Offset at,
    String text, {
    required double size,
    required Color color,
    bool center = false,
    bool bold = false,
    bool mono = false,
    double? maxWidth,
  }) {
    // Mona Sans for the labels of the chrome, Monaspace with tabular
    // figures for a counted value, as in the game's HUD.
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontFamily: mono ? HzFont.mono : HzFont.sans,
          package: HzFont.package,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
          letterSpacing: mono ? 0 : 0.5,
          fontFeatures: mono ? const [FontFeature.tabularFigures()] : null,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: maxWidth == null ? null : '…',
    )..layout(maxWidth: maxWidth ?? double.infinity);
    painter.paint(canvas, center ? at - Offset(painter.width / 2, 0) : at);
    painter.dispose();
  }

  void _icon(
    Canvas canvas,
    Offset at,
    IconData icon,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          color: color,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
    painter.dispose();
  }

  static Offset _dir(double angle) => Offset(sin(angle), -cos(angle));
  static double _angleOf(Offset v) => atan2(v.dx, -v.dy);

  /// Progress from 0 to 1 while the clock passes from [from] to [to].
  double _seg(double from, double to) =>
      ((_t - from) / (to - from)).clamp(0.0, 1.0);

  bool _between(double from, double to) => _t >= from && _t < to;

  /// Whether one of [times] happened just now.
  bool _pulse(List<double> times, {double width = 0.05}) =>
      times.any((s) => _t >= s - 0.01 && _t < s + width);

  /// Muzzle flash right after one of [shots].
  double _flash(List<double> shots) {
    for (final shot in shots) {
      final p = _seg(shot, shot + 0.05);
      if (p > 0 && p < 1) {
        return 1 - p;
      }
    }
    return 0;
  }

  static double _ease(double p) => Curves.easeInOut.transform(p);
}
