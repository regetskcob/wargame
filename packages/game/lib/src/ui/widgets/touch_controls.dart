import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/touch_input.dart';
import '../../theme.dart';

/// Twin stick controls for holding the phone with both hands.
///
/// The lower part of each half of the screen is one big touch area. The left
/// thumb drives (up is forward, sideways turns), the right thumb aims the
/// turret and fires as soon as the stick is pushed past the outer ring. The
/// sticks appear wherever the thumb lands, so nobody has to find a button.
class TouchControls extends StatelessWidget {
  const TouchControls({required this.input, super.key});

  final TouchInput input;

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
          final zoneTop = height * 0.3;
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
                  label: 'FAHREN',
                  homeOnRight: false,
                  onChanged: (v) {
                    final active = v.distance > 0.18;
                    input
                      ..left = active && v.dx < -0.3
                      ..right = active && v.dx > 0.3
                      ..thrust = active && v.dy < -0.25
                      ..brake = active && v.dy > 0.25;
                  },
                  onReleased: () => input
                    ..left = false
                    ..right = false
                    ..thrust = false
                    ..brake = false,
                ),
              ),
              Positioned(
                right: 0,
                top: zoneTop,
                bottom: 0,
                width: zoneWidth,
                child: _FloatingStick(
                  size: stick,
                  label: 'ZIELEN · FEUER',
                  homeOnRight: true,
                  ring: fireRing,
                  onChanged: (v) {
                    if (v.distance > 0.18) {
                      input.aim = atan2(v.dx, -v.dy);
                    }
                    input.aimFire = v.distance > fireRing;
                  },
                  onReleased: () => input.aimFire = false,
                ),
              ),
            ],
          );
        },
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
        final active = _origin != null;
        final centre = _origin ?? home;
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
            children: [
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
                      label: widget.label,
                      active: active,
                      knob: _knob,
                      ring: widget.ring,
                      firing:
                          widget.ring != null &&
                          _knob.distance / _radius > widget.ring!,
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

class _StickFace extends StatelessWidget {
  const _StickFace({
    required this.size,
    required this.label,
    required this.active,
    required this.knob,
    required this.firing,
    this.ring,
  });

  final double size;
  final String label;
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
              color: active ? BwColors.amber : BwColors.sand,
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
                color: (firing ? BwColors.danger : BwColors.sand).withValues(
                  alpha: firing ? 0.9 : 0.4,
                ),
                width: 1.5,
              ),
            ),
          ),
        Positioned(
          top: size * 0.07,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              letterSpacing: 1.5,
              color: BwColors.textDim,
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
                  ? BwColors.danger
                  : active
                  ? BwColors.amber
                  : BwColors.olive,
              border: Border.all(color: BwColors.sand, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
