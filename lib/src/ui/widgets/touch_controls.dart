import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../../app/env.dart';
import '../../game/special_weapon.dart';
import '../../game/touch_input.dart';
import '../theme.dart';
import '../../l10n/l10n.dart';
import '../../vision/vision_support.dart';

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
///
/// On an Apple Vision Pro there is no right stick: a pinch lands where the
/// player looks, so looking at a spot and pinching aims there and fires for
/// as long as the fingers stay together. The left hand still drives with a
/// pinch and drag in the lower left.
class TouchControls extends StatelessWidget {
  const TouchControls({
    required this.input,
    required this.special,
    this.assist = true,
    this.onLook,
    super.key,
  });

  final TouchInput input;
  final ValueListenable<(SpecialWeapon, int)?> special;

  /// Whether the aim assist and its button are offered: in a round on
  /// every level, not where the screen does not ask for it.
  final bool assist;

  /// On a Vision Pro: the spot looked at when pinching, in global pixels,
  /// for a game that turns screen points into the world. Without it the
  /// turret points from the middle of the screen to the spot.
  final ValueChanged<Offset>? onLook;

  /// Share of the stick radius past which the aim stick fires.
  static const fireRing = 0.62;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.symmetric(
        horizontal: HzSpace.s12,
        vertical: HzSpace.s8,
      ),
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
              // Under the drive stick, so a pinch in its corner drives.
              if (onVision)
                Positioned.fill(
                  child: _LookToFire(input: input, onLook: onLook),
                ),
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
              if (!onVision)
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

/// Vision Pro: aims at the spot the player looks at when pinching and fires
/// while the pinch is held. Moving the pinched hand does not move the aim:
/// visionOS reports the hand, not the eyes, after the first touch.
class _LookToFire extends StatefulWidget {
  const _LookToFire({required this.input, this.onLook});

  final TouchInput input;
  final ValueChanged<Offset>? onLook;

  @override
  State<_LookToFire> createState() => _LookToFireState();
}

class _LookToFireState extends State<_LookToFire> {
  /// Pinches held right now; both hands may pinch at once.
  final _held = <int>{};

  void _down(PointerDownEvent e, Size zone) {
    if (!mounted) {
      return;
    }
    _held.add(e.pointer);
    final input = widget.input;
    final look = widget.onLook;
    if (look != null) {
      // The game aims at the point itself, which keeps up when the camera
      // stops at the edge of the map and the tank is off centre.
      input.aim = null;
      look(e.position);
    } else {
      final from = e.localPosition - zone.center(Offset.zero);
      input.aim = atan2(from.dx, -from.dy);
    }
    input
      ..aimHeld = true
      ..aimFire = true;
  }

  void _up(PointerEvent e) {
    // A finger lifted after the controls went away: dispose let go already.
    if (!mounted) {
      return;
    }
    if (_held.remove(e.pointer) && _held.isEmpty) {
      widget.input
        ..aimFire = false
        ..aimHeld = false;
    }
  }

  @override
  void dispose() {
    if (_held.isNotEmpty) {
      widget.input
        ..aimFire = false
        ..aimHeld = false;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => _down(e, constraints.biggest),
        onPointerUp: _up,
        onPointerCancel: _up,
        // Where the right stick rests elsewhere, a quiet note of how to fire.
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(HzSpace.s8),
            child: IgnorePointer(
              child: _StickLabel(tr('HINSEHEN · PINCH', 'LOOK · PINCH')),
            ),
          ),
        ),
      ),
    );
  }
}

/// Switches the aim assist on and off. It starts on: on a phone the turret
/// finding the enemy by itself leaves both thumbs for driving and dodging.
class _AssistToggle extends StatefulWidget {
  const _AssistToggle({required this.input});

  static const height = HzSize.touch;

  final TouchInput input;

  @override
  State<_AssistToggle> createState() => _AssistToggleState();
}

class _AssistToggleState extends State<_AssistToggle> {
  @override
  void initState() {
    super.initState();
    widget.input
      ..assist = true
      ..assistOwner = this;
  }

  @override
  void dispose() {
    if (identical(widget.input.assistOwner, this)) {
      widget.input
        ..assist = false
        ..assistFire = false
        ..assistOwner = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.input.assist;
    // On is a selection: the 2 px line in the accent on its tint, the word
    // AN/AUS says it as well.
    final color = on ? GameColors.accentText : GameColors.textMuted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        widget.input
          ..assist = !on
          ..assistFire = false;
      }),
      child: Container(
        height: _AssistToggle.height,
        padding: const EdgeInsets.symmetric(horizontal: HzSpace.s12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HzRadius.r6),
          // Dark in both states, so the label reads on snow and sand too.
          color: (on ? GameColors.accentTint : GameColors.bg).withValues(
            alpha: 0.85,
          ),
        ),
        // Over the face, so switching never shifts the label.
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HzRadius.r6),
          border: on
              ? Border.all(color: color, width: HzLine.selection)
              : Border.all(color: GameColors.lineStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(HorizontSymbols.gpsFixed, size: HzIconSize.row, color: color),
            const SizedBox(width: HzSpace.s8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  on
                      ? tr('ZIELHILFE AN', 'AIM ASSIST ON')
                      : tr('ZIELHILFE AUS', 'AIM ASSIST OFF'),
                  style: GameType.kennung.copyWith(color: color),
                ),
                // It also pulls the trigger, which spends the shells: say so.
                Text(
                  on
                      ? tr('feuert selbst', 'fires by itself')
                      : tr('du zielst selbst', 'you aim yourself'),
                  style: GameType.caption.copyWith(color: GameColors.text),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Button for the special weapon, firing while held: a free-standing
/// plate with the radius of a card, the weapon's colour only on its gem.
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
  /// Fingers on the button: a second one resting there kept firing only
  /// until the first lifted.
  final _fingers = <int>{};
  bool _down = false;

  void _press(PointerEvent e) => _set(_fingers..add(e.pointer));

  void _lift(PointerEvent e) => _set(_fingers..remove(e.pointer));

  void _set(Set<int> fingers) {
    // Fingers still come up after the button went away, when the weapon
    // ran out or the round ended under them. Dispose let go already, and
    // a late release would have stopped a new button held meanwhile.
    if (!mounted) {
      return;
    }
    final down = fingers.isNotEmpty;
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
    final mark = GameType.kennung.copyWith(
      color: GameColors.text,
      letterSpacing: 0,
    );
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _press,
      onPointerUp: _lift,
      onPointerCancel: _lift,
      child: Container(
        width: _SpecialButton.size,
        height: _SpecialButton.size,
        // Held, it shows the selection: the accent line on its tint. The
        // line lies over the face, so pressing never moves the label.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HzRadius.r10),
          color: (_down ? GameColors.accentTint : GameColors.sunken).withValues(
            alpha: 0.85,
          ),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HzRadius.r10),
          border: _down
              ? Border.all(
                  color: GameColors.accentText,
                  width: HzLine.selection,
                )
              : Border.all(color: GameColors.lineStrong),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              HorizontSymbols.diamond,
              size: HzIconSize.inline,
              color: color,
            ),
            Text(switch (widget.weapon) {
              SpecialWeapon.drone => tr('DROHNE', 'DRONE'),
              SpecialWeapon.mortar => tr('MÖRSER', 'MORTAR'),
              _ => tr('GRANATE', 'GRENADE'),
            }, style: mark),
            Text('×${widget.charges}', style: mark),
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

  /// Further fingers in the zone and where they are, latest last. When the
  /// steering thumb lifts, the latest one takes the stick over: a thumb
  /// set down again before the other came up used to steer nothing until
  /// it was lifted and put down once more.
  final _others = <int, Offset>{};

  double get _radius => widget.size / 2 - widget.size * 0.17;

  void _down(PointerDownEvent e, Size zone) {
    if (!mounted) {
      return;
    }
    if (_pointer != null) {
      _others[e.pointer] = e.localPosition;
      return;
    }
    _grab(e.pointer, e.localPosition, zone);
    _move(e);
  }

  void _grab(int pointer, Offset at, Size zone) {
    _pointer = pointer;
    final half = widget.size / 2;
    setState(() {
      _origin = Offset(
        at.dx.clamp(half, max(half, zone.width - half)),
        at.dy.clamp(half, max(half, zone.height - half)),
      );
      _knob = Offset.zero;
    });
  }

  /// A finger in the zone came up or was cancelled by the system.
  void _lift(PointerEvent e, Size zone) {
    if (!mounted || _others.remove(e.pointer) != null) {
      return;
    }
    if (_pointer != e.pointer) {
      return;
    }
    if (_others.isEmpty) {
      _release();
      return;
    }
    final next = _others.keys.last;
    _grab(next, _others.remove(next)!, zone);
    // Centred under the thumb: it steers from where it rests.
    widget.onChanged(Offset.zero);
  }

  void _move(PointerEvent e) {
    final origin = _origin;
    if (!mounted || origin == null) {
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
    _pointer = null;
    _others.clear();
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
            } else if (_others.containsKey(e.pointer)) {
              _others[e.pointer] = e.localPosition;
            }
          },
          onPointerUp: (e) => _lift(e, zone),
          onPointerCancel: (e) => _lift(e, zone),
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

/// Name of a stick on a dark plate, readable on any ground.
class _StickLabel extends StatelessWidget {
  const _StickLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: GameColors.sunken.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(HzRadius.r6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HzSpace.s8,
          vertical: HzSpace.s2,
        ),
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: GameType.kennung.copyWith(color: GameColors.text),
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
          // A held stick is the selection, its ring the 2 px accent line.
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: GameColors.sunken.withValues(alpha: active ? 0.55 : 0.3),
            border: Border.all(
              color: active ? GameColors.accentText : GameColors.text,
              width: HzLine.selection,
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
                color: (firing ? GameColors.critical : GameColors.text)
                    .withValues(alpha: firing ? 0.9 : 0.4),
                width: firing ? HzLine.selection : HzLine.hairline,
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
              color: firing ? GameColors.critical : GameColors.accent,
              border: Border.all(color: GameColors.sunken),
            ),
          ),
        ),
      ],
    );
  }
}
