import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../game/touch_input.dart';

/// An enemy tank standing still on the training ground, to be shot at.
class PracticeTarget {
  PracticeTarget(this.at);

  Offset at;

  /// Seconds until it is back after a hit, 0 while it stands.
  double down = 0;

  bool get standing => down <= 0;
}

class PracticeShell {
  PracticeShell(this.at, this.dir);

  Offset at;
  final Offset dir;
}

class PracticeGrenade {
  PracticeGrenade(this.from, this.to);

  final Offset from;
  final Offset to;

  /// Flight from 0 to 1.
  double t = 0;
}

class PracticeBlast {
  PracticeBlast(this.at, {this.big = false});

  final Offset at;
  final bool big;
  double t = 0;
}

/// The training ground once the player takes over a tutorial step: their
/// own tank drives, aims and fires with the game's controls, a couple of
/// enemy tanks stand around to be hit and come back after a moment.
///
/// It is no copy of the game's physics, only close enough to learn the
/// controls by: positions are in pixels of the stage, angles the game's
/// (0 points up, positive turns clockwise).
class TutorialPractice extends ChangeNotifier {
  TutorialPractice({
    required this.touch,
    required Rect bounds,
    this.grenades = false,
    TouchInput? input,
  }) : input = input ?? TouchInput(),
       _bounds = bounds,
       pos = bounds.center {
    for (var i = 0; i < 2; i++) {
      targets.add(PracticeTarget(_spot(i)));
    }
    _nextSpot = 2;
  }

  /// Touch reads [input] like the game's touch controls, otherwise the keys
  /// and the mouse.
  final bool touch;

  /// Whether the special weapon is loaded, on its own step.
  final bool grenades;

  /// Written by the touch controls laid over the stage.
  final TouchInput input;

  Rect _bounds;

  /// Where the stage is free, below the card.
  Rect get bounds => _bounds;
  set bounds(Rect value) {
    _bounds = value;
    pos = _clamp(pos);
  }

  Offset pos;
  double heading = 0;
  double turret = 0;

  /// Muzzle flash, from 1 down to 0.
  double flash = 0;
  int hits = 0;
  late int charges = grenades ? 3 : 0;

  /// Where the mouse points, desktop only.
  Offset? mouse;

  /// Held mouse button, desktop only.
  bool mouseDown = false;

  /// The keys of the last tick, for drawing them lit.
  Set<LogicalKeyboardKey> keys = const {};

  final targets = <PracticeTarget>[];
  final shells = <PracticeShell>[];
  final lobs = <PracticeGrenade>[];
  final blasts = <PracticeBlast>[];

  /// Track marks: where the chains were and which way the hull pointed.
  final trail = <(Offset, double)>[];

  var _reload = 0.0;
  var _refill = 0.0;
  var _specialWas = false;
  late int _nextSpot;

  static const _turnRate = 2.6;
  static const _turretRate = 4.5;
  static const _reloadTime = 0.45;
  static const _flight = 0.8;

  /// Places for the targets, as shares of the stage.
  static const _spots = [
    (0.8, 0.3),
    (0.2, 0.35),
    (0.72, 0.72),
    (0.28, 0.7),
    (0.5, 0.18),
    (0.9, 0.55),
    (0.1, 0.55),
  ];

  /// The same size as the demo scenes draw their tank in.
  double get tankSize =>
      (min(_bounds.width, _bounds.height) * 0.2).clamp(36.0, 72.0);

  double get _speed => tankSize * 2.4;

  static Offset dir(double angle) => Offset(sin(angle), -cos(angle));
  static double angleOf(Offset v) => atan2(v.dx, -v.dy);
  static double _wrap(double a) => atan2(sin(a), cos(a));

  Offset _spot(int i) {
    final (x, y) = _spots[i % _spots.length];
    return Offset(
      _bounds.left + _bounds.width * x,
      _bounds.top + _bounds.height * y,
    );
  }

  Offset _clamp(Offset p) {
    final m = tankSize * 0.6;
    return Offset(
      p.dx.clamp(_bounds.left + m, max(_bounds.left + m, _bounds.right - m)),
      p.dy.clamp(_bounds.top + m, max(_bounds.top + m, _bounds.bottom - m)),
    );
  }

  PracticeTarget? _nearest() {
    PracticeTarget? best;
    for (final t in targets) {
      if (t.standing &&
          (best == null || (t.at - pos).distance < (best.at - pos).distance)) {
        best = t;
      }
    }
    return best;
  }

  /// Moves everything on by [dt] seconds; [pressed] are the keys held now.
  void tick(double dt, {Set<LogicalKeyboardKey> pressed = const {}}) {
    dt = min(dt, 0.05);
    keys = pressed;
    _drive(dt);
    final fire = _aim(dt);
    _reload -= dt;
    if (fire && _reload <= 0) {
      shells.add(
        PracticeShell(pos + dir(turret) * tankSize * 0.6, dir(turret)),
      );
      _reload = _reloadTime;
      flash = 1;
    }
    flash = max(0, flash - dt * 6);
    _special(dt);
    _fly(dt);
    notifyListeners();
  }

  bool _held(LogicalKeyboardKey a, LogicalKeyboardKey b) =>
      keys.contains(a) || keys.contains(b);

  void _drive(double dt) {
    var distance = 0.0;
    if (touch) {
      final d = input.drive;
      if (d != null) {
        // Like the game's touch steering: turn toward the thumb and drive,
        // slower while the hull still points elsewhere.
        final want = atan2(d.$1, -d.$2);
        final diff = _wrap(want - heading);
        heading += diff.clamp(-_turnRate * dt, _turnRate * dt);
        final length = min(1.0, sqrt(d.$1 * d.$1 + d.$2 * d.$2));
        distance = _speed * length * max(0, cos(diff)) * dt;
      }
    } else {
      final right = _held(
        LogicalKeyboardKey.keyD,
        LogicalKeyboardKey.arrowRight,
      );
      final left = _held(LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft);
      heading += ((right ? 1 : 0) - (left ? 1 : 0)) * _turnRate * dt;
      final go = _held(LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp)
          ? 1.0
          : _held(LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown)
          ? -0.5
          : 0.0;
      distance = _speed * go * dt;
    }
    heading = _wrap(heading);
    if (distance == 0) {
      return;
    }
    pos = _clamp(pos + dir(heading) * distance);
    if (trail.isEmpty || (trail.last.$1 - pos).distance > tankSize * 0.12) {
      trail.add((pos, heading));
      if (trail.length > 60) {
        trail.removeAt(0);
      }
    }
  }

  /// Turns the turret and tells whether to fire.
  bool _aim(double dt) {
    double? want;
    var fire = false;
    if (touch) {
      final target = _nearest();
      if (input.aimHeld && input.aim != null) {
        want = input.aim;
        fire = input.aimFire;
      } else if (input.assist && target != null) {
        // The assist only fires once the turret is on the target.
        want = angleOf(target.at - pos);
        fire = _wrap(want - turret).abs() < 0.12;
      } else {
        want = input.aim;
      }
      input.assistFire = fire && !input.aimHeld;
    } else {
      final q = keys.contains(LogicalKeyboardKey.keyQ);
      final e = keys.contains(LogicalKeyboardKey.keyE);
      if (q || e) {
        // The keys take over from the mouse until it moves again.
        mouse = null;
        turret += ((e ? 1 : 0) - (q ? 1 : 0)) * _turretRate * dt;
      } else if (mouse case final m?) {
        want = angleOf(m - pos);
      }
      fire = keys.contains(LogicalKeyboardKey.space) || mouseDown;
    }
    if (want != null) {
      turret += _wrap(want - turret).clamp(-_turretRate * dt, _turretRate * dt);
    }
    turret = _wrap(turret);
    return fire;
  }

  void _special(double dt) {
    final pressed = touch
        ? input.special
        : keys.contains(LogicalKeyboardKey.keyF);
    if (grenades && pressed && !_specialWas && charges > 0) {
      final aimed = !touch && mouse != null
          ? mouse!
          : pos + dir(turret) * tankSize * 4;
      lobs.add(PracticeGrenade(pos, _clamp(aimed)));
      charges--;
    }
    _specialWas = pressed;
    if (grenades && charges == 0) {
      // Endless in practice: after a short wait the launcher is full again.
      _refill += dt;
      if (_refill > 2.5) {
        charges = 3;
        _refill = 0;
      }
    }
  }

  void _fly(double dt) {
    final reach = tankSize * 0.45;
    final outside = _bounds.inflate(tankSize);
    for (final shell in [...shells]) {
      shell.at += shell.dir * tankSize * 9 * dt;
      final hit = targets.where(
        (t) => t.standing && (t.at - shell.at).distance < reach,
      );
      if (hit.isNotEmpty) {
        _hit(hit.first);
        shells.remove(shell);
      } else if (!outside.contains(shell.at)) {
        shells.remove(shell);
      }
    }
    for (final lob in [...lobs]) {
      lob.t += dt / _flight;
      if (lob.t >= 1) {
        lobs.remove(lob);
        blasts.add(PracticeBlast(lob.to, big: true));
        for (final t in targets) {
          if (t.standing && (t.at - lob.to).distance < tankSize * 1.1) {
            _hit(t, blast: false);
          }
        }
      }
    }
    for (final blast in [...blasts]) {
      blast.t += dt / 0.45;
      if (blast.t >= 1) {
        blasts.remove(blast);
      }
    }
    for (final t in targets) {
      if (t.standing) {
        continue;
      }
      t.down -= dt;
      if (t.standing) {
        t.at = _freeSpot();
      }
    }
  }

  void _hit(PracticeTarget target, {bool blast = true}) {
    target.down = 1.4;
    hits++;
    if (blast) {
      blasts.add(PracticeBlast(target.at));
    }
  }

  /// The next place for a target that is clear of the tank and the others.
  Offset _freeSpot() {
    for (var i = 0; i < _spots.length; i++) {
      final at = _spot(_nextSpot++);
      final clear =
          (at - pos).distance > tankSize * 2.5 &&
          targets.every((t) => !t.standing || (t.at - at).distance > tankSize);
      if (clear) {
        return at;
      }
    }
    return _spot(_nextSpot++);
  }
}
