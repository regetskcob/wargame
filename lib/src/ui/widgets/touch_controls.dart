import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/env.dart';
import '../../game/special_weapon.dart';
import '../../game/touch_input.dart';
import '../theme.dart';
import '../../l10n/l10n.dart';

/// Twin stick controls for holding the phone with both hands.
///
/// The lower part of each half of the screen is one big touch area. The left
/// thumb points where the tank should go: it turns that way by itself and
/// drives, there is no fiddling with the tracks. The right thumb aims the
/// turret and fires as soon as the stick is pushed past the outer ring.
/// While it rests, the aim assist (switchable with the button above the
/// stick) turns the turret onto the nearest enemy in range and fires. The
/// sticks appear wherever the thumb lands, so nobody has to find a button.
/// A special weapon from a gem gets a button of its own, next to the assist.
class TouchControls extends StatelessWidget {
  const TouchControls({
    required this.input,
    required this.special,
    this.assist = true,
    super.key,
  });

  final TouchInput input;
  final ValueListenable<(SpecialWeapon, int)?> special;

  /// Whether the aim assist and its button are offered. Not on hard.
  final bool assist;

  /// Share of the stick radius past which the aim stick fires.
  static const fireRing = 0.62;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final stick = (min(width, height) * 0.36).clamp(112.0, 160.0);
          // The top third stays free for the HUD, the middle for the view.
          // Upright phones have the height to spare and keep more of it.
          final upright = height > width;
          final zoneTop = height * (upright ? 0.4 : 0.3);
          // The buttons sit just above the aim stick, in reach of the right
          // thumb and clear of the plates along the top, which in a defense
          // round fold out over the upper right corner. They keep enough
          // room above the stick for its label.
          final buttonTop = max(zoneTop, height - stick - 104);
          // Upright, the aim zone starts below the buttons rather than around
          // them: a thumb landing for the stick toggled the assist now and
          // then, and parking it far above the stick put it out of reach.
          final aimTop = upright
              ? buttonTop + _SpecialButton.size + 4
              : zoneTop;
          final zoneWidth = width * 0.44;
          return Stack(
            children: [
              Positioned(
                left: 0,
                top: zoneTop,
                bottom: 0,
                width: zoneWidth,
                child: _FloatingStick(
                  size: stick,
                  label: tr('FAHREN', 'DRIVE'),
                  homeOnRight: false,
                  onChanged: (v) =>
                      input.drive = v.distance > 0.18 ? (v.dx, v.dy) : null,
                  onReleased: () => input.drive = null,
                ),
              ),
              Positioned(
                right: 0,
                top: aimTop,
                bottom: 0,
                width: zoneWidth,
                child: _FloatingStick(
                  size: stick,
                  label: tr('ZIELEN · FEUER', 'AIM · FIRE'),
                  homeOnRight: true,
                  ring: fireRing,
                  onChanged: (v) {
                    input.aimHeld = true;
                    if (v.distance > 0.18) {
                      input.aim = atan2(v.dx, -v.dy);
                    }
                    input.aimFire = v.distance > fireRing;
                  },
                  onReleased: () => input
                    ..aimFire = false
                    ..aimHeld = false,
                ),
              ),
              // Flush over the aim stick, moving aside for a special weapon
              // and bottom-aligned with its button.
              if (assist)
                ValueListenableBuilder<(SpecialWeapon, int)?>(
                  valueListenable: special,
                  builder: (context, loadout, child) => Positioned(
                    right: loadout == null ? 8 : 16 + _SpecialButton.size,
                    top: buttonTop + _SpecialButton.size - _AssistToggle.height,
                    child: child!,
                  ),
                  child: _AssistToggle(input: input),
                ),
              Positioned(
                right: 8,
                top: buttonTop,
                child: ValueListenableBuilder<(SpecialWeapon, int)?>(
                  valueListenable: special,
                  builder: (context, loadout, _) => loadout == null
                      ? const SizedBox()
                      : _SpecialButton(
                          weapon: loadout.$1,
                          charges: loadout.$2,
                          onHeld: (held) => input.special = held,
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Switches the aim assist on and off. It starts on: on a phone the turret
/// finding the enemy by itself leaves both thumbs for driving and dodging.
class _AssistToggle extends StatefulWidget {
  const _AssistToggle({required this.input});

  static const height = 44.0;

  final TouchInput input;

  @override
  State<_AssistToggle> createState() => _AssistToggleState();
}

class _AssistToggleState extends State<_AssistToggle> {
  @override
  void initState() {
    super.initState();
    widget.input.assist = true;
  }

  @override
  void dispose() {
    widget.input
      ..assist = false
      ..assistFire = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.input.assist;
    final color = on ? GameColors.amber : GameColors.textDim;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        widget.input
          ..assist = !on
          ..assistFire = false;
      }),
      child: Container(
        height: _AssistToggle.height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_AssistToggle.height / 2),
          // Dark in both states, so the label reads on snow and sand too.
          color: const Color(0xB3141A0E),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gps_fixed_outlined, size: 18, color: color),
            const SizedBox(width: 6),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  on
                      ? tr('ZIELHILFE AN', 'AIM ASSIST ON')
                      : tr('ZIELHILFE AUS', 'AIM ASSIST OFF'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                // It also pulls the trigger, which spends the shells: say so.
                Text(
                  on
                      ? tr('feuert selbst', 'fires by itself')
                      : tr('du zielst selbst', 'you aim yourself'),
                  style: const TextStyle(
                    fontSize: 9,
                    letterSpacing: 0.3,
                    color: GameColors.text,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Round button for the special weapon, firing while held.
class _SpecialButton extends StatefulWidget {
  const _SpecialButton({
    required this.weapon,
    required this.charges,
    required this.onHeld,
  });

  static const size = 68.0;

  final SpecialWeapon weapon;
  final int charges;
  final ValueChanged<bool> onHeld;

  @override
  State<_SpecialButton> createState() => _SpecialButtonState();
}

class _SpecialButtonState extends State<_SpecialButton> {
  bool _down = false;

  void _set(bool down) {
    if (_down == down) {
      return;
    }
    setState(() => _down = down);
    widget.onHeld(down);
  }

  @override
  void dispose() {
    if (_down) {
      widget.onHeld(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.weapon.color;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: Container(
        width: _SpecialButton.size,
        height: _SpecialButton.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _down ? color.withValues(alpha: 0.6) : const Color(0x88000000),
          border: Border.all(color: color, width: 2.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.diamond_outlined, size: 18, color: color),
            Text(switch (widget.weapon) {
              SpecialWeapon.drone => tr('DROHNE', 'DRONE'),
              SpecialWeapon.mortar => tr('MÖRSER', 'MORTAR'),
              _ => tr('GRANATE', 'GRENADE'),
            }, style: const TextStyle(fontSize: 10, letterSpacing: 0.5)),
            Text(
              '×${widget.charges}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// A stick that appears under the thumb inside its zone and reports its
/// deflection as a vector of length 0 to 1. While untouched a faint copy shows
/// where the thumb usually rests.
class _FloatingStick extends StatefulWidget {
  const _FloatingStick({
    required this.size,
    required this.label,
    required this.homeOnRight,
    required this.onChanged,
    required this.onReleased,
    this.ring,
  });

  final double size;
  final String label;
  final bool homeOnRight;
  final ValueChanged<Offset> onChanged;
  final VoidCallback onReleased;

  /// Radius share that is marked as a ring, for the fire threshold.
  final double? ring;

  @override
  State<_FloatingStick> createState() => _FloatingStickState();
}

class _FloatingStickState extends State<_FloatingStick> {
  Offset? _origin;
  Offset _knob = Offset.zero;
  int? _pointer;

  double get _radius => widget.size / 2 - widget.size * 0.17;

  void _down(PointerDownEvent e, Size zone) {
    if (_pointer != null) {
      return;
    }
    _pointer = e.pointer;
    final half = widget.size / 2;
    setState(() {
      _origin = Offset(
        e.localPosition.dx.clamp(half, max(half, zone.width - half)),
        e.localPosition.dy.clamp(half, max(half, zone.height - half)),
      );
      _knob = Offset.zero;
    });
    _move(e);
  }

  void _move(PointerEvent e) {
    final origin = _origin;
    if (origin == null) {
      return;
    }
    final delta = e.localPosition - origin;
    final length = delta.distance;
    final clamped = length > _radius ? delta / length * _radius : delta;
    setState(() => _knob = clamped);
    widget.onChanged(clamped / _radius);
  }

  void _release() {
    _pointer = null;
    setState(() {
      _origin = null;
      _knob = Offset.zero;
    });
    widget.onReleased();
  }

  @override
  void dispose() {
    if (_origin != null) {
      widget.onReleased();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final zone = constraints.biggest;
        final half = widget.size / 2;
        final home = Offset(
          widget.homeOnRight ? zone.width - half - 6 : half + 6,
          zone.height - half - 6,
        );
        // The picture of the controls shows both thumbs at work, see
        // Env.shotSticks: driving ahead to the right, aiming up left past
        // the fire ring.
        final posed = Env.shotSticks && _origin == null;
        final active = _origin != null || posed;
        final centre = _origin ?? home;
        final knob = posed
            ? Offset(widget.homeOnRight ? -0.55 : 0.35, -0.75) * _radius
            : _knob;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _down(e, zone),
          onPointerMove: (e) {
            if (_pointer == e.pointer) {
              _move(e);
            }
          },
          onPointerUp: (e) {
            if (_pointer == e.pointer) {
              _release();
            }
          },
          onPointerCancel: (e) {
            if (_pointer == e.pointer) {
              _release();
            }
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The label sits above the ring rather than inside it: in there
              // the circle narrows and cut through the text, and the faded
              // idle stick made it hard to read on the bright ground. It is
              // centred over the stick but kept inside the zone, since a long
              // label is wider than the ring and the sticks rest at the edge.
              Positioned(
                left: 0,
                right: 0,
                top: centre.dy - half - 26,
                child: IgnorePointer(
                  child: CustomSingleChildLayout(
                    delegate: _CentreInside(centre.dx),
                    child: _StickLabel(widget.label),
                  ),
                ),
              ),
              Positioned(
                left: centre.dx - half,
                top: centre.dy - half,
                width: widget.size,
                height: widget.size,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: active ? 1 : 0.55,
                    child: _StickFace(
                      size: widget.size,
                      active: active,
                      knob: knob,
                      ring: widget.ring,
                      firing:
                          widget.ring != null &&
                          knob.distance / _radius > widget.ring!,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Centres its child on [x] but shifts it back inside the available width.
class _CentreInside extends SingleChildLayoutDelegate {
  const _CentreInside(this.x);

  final double x;

  @override
  Size getSize(BoxConstraints constraints) => Size(constraints.maxWidth, 24);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(Size(constraints.maxWidth, 24));

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    (x - childSize.width / 2).clamp(0, max(0, size.width - childSize.width)),
    0,
  );

  @override
  bool shouldRelayout(_CentreInside oldDelegate) => oldDelegate.x != x;
}

/// Name of a stick on a dark pill, readable on any ground.
class _StickLabel extends StatelessWidget {
  const _StickLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: GameColors.sand,
          ),
        ),
      ),
    );
  }
}

class _StickFace extends StatelessWidget {
  const _StickFace({
    required this.size,
    required this.active,
    required this.knob,
    required this.firing,
    this.ring,
  });

  final double size;
  final bool active;
  final Offset knob;
  final bool firing;
  final double? ring;

  @override
  Widget build(BuildContext context) {
    final knobSize = size * 0.34;
    final radius = size / 2 - size * 0.17;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(active ? 0x88000000 : 0x44000000),
            border: Border.all(
              color: active ? GameColors.amber : GameColors.sand,
              width: 2,
            ),
          ),
        ),
        if (ring != null)
          Container(
            width: radius * 2 * ring!,
            height: radius * 2 * ring!,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: (firing ? GameColors.danger : GameColors.sand)
                    .withValues(alpha: firing ? 0.9 : 0.4),
                width: 1.5,
              ),
            ),
          ),
        Transform.translate(
          offset: knob,
          child: Container(
            width: knobSize,
            height: knobSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: firing
                  ? GameColors.danger
                  : active
                  ? GameColors.amber
                  : GameColors.olive,
              border: Border.all(color: GameColors.sand, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
