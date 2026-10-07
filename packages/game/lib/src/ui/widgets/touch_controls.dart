import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/touch_input.dart';
import '../../theme.dart';

/// Two sticks and a fire button, the usual twin stick layout for a tank: the
/// left thumb drives (up is forward, sideways turns), the right thumb aims the
/// turret and fires when pushed to the edge, and FEUER fires without aiming.
class TouchControls extends StatelessWidget {
  const TouchControls({required this.input, super.key});

  final TouchInput input;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shortest = min(constraints.maxWidth, constraints.maxHeight);
          final stick = (shortest * 0.34).clamp(112.0, 170.0);
          return Stack(
            children: [
              Align(
                alignment: Alignment.bottomLeft,
                child: _Stick(
                  size: stick,
                  label: 'FAHREN',
                  onChanged: (v, _) {
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
              Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _HoldButton(
                      icon: Icons.gps_fixed,
                      label: 'FEUER',
                      size: stick * 0.62,
                      accent: BwColors.danger,
                      onChanged: (down) => input.fire = down,
                    ),
                    const SizedBox(width: 12),
                    _Stick(
                      size: stick,
                      label: 'ZIELEN',
                      onChanged: (v, _) {
                        if (v.distance > 0.18) {
                          input.aim = atan2(v.dx, -v.dy);
                        }
                        input.aimFire = v.distance > 0.82;
                      },
                      onReleased: () => input.aimFire = false,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A stick that reports its deflection as a vector of length 0 to 1.
class _Stick extends StatefulWidget {
  const _Stick({
    required this.size,
    required this.label,
    required this.onChanged,
    required this.onReleased,
  });

  final double size;
  final String label;
  final void Function(Offset deflection, bool active) onChanged;
  final VoidCallback onReleased;

  @override
  State<_Stick> createState() => _StickState();
}

class _StickState extends State<_Stick> {
  Offset _knob = Offset.zero;
  bool _active = false;
  int? _pointer;

  double get _radius => widget.size / 2 - widget.size * 0.17;

  void _update(Offset local) {
    final delta = local - Offset(widget.size / 2, widget.size / 2);
    final length = delta.distance;
    final clamped = length > _radius ? delta / length * _radius : delta;
    setState(() {
      _active = true;
      _knob = clamped;
    });
    widget.onChanged(clamped / _radius, true);
  }

  void _release() {
    _pointer = null;
    setState(() {
      _active = false;
      _knob = Offset.zero;
    });
    widget.onReleased();
  }

  @override
  void dispose() {
    if (_active) {
      widget.onReleased();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final knob = widget.size * 0.34;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        _pointer ??= e.pointer;
        if (_pointer == e.pointer) {
          _update(e.localPosition);
        }
      },
      onPointerMove: (e) {
        if (_pointer == e.pointer) {
          _update(e.localPosition);
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
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(_active ? 0x88000000 : 0x55000000),
                border: Border.all(
                  color: _active ? BwColors.amber : BwColors.sand,
                  width: 2,
                ),
              ),
            ),
            Positioned(
              top: widget.size * 0.07,
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.5,
                  color: BwColors.textDim,
                ),
              ),
            ),
            Transform.translate(
              offset: _knob,
              child: Container(
                width: knob,
                height: knob,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _active ? BwColors.amber : BwColors.olive,
                  border: Border.all(color: BwColors.sand, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoldButton extends StatefulWidget {
  const _HoldButton({
    required this.icon,
    required this.label,
    required this.onChanged,
    this.size = 76,
    this.accent = BwColors.olive,
  });

  final IconData icon;
  final String label;
  final ValueChanged<bool> onChanged;
  final double size;
  final Color accent;

  @override
  State<_HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<_HoldButton> {
  bool _down = false;

  void _set(bool down) {
    if (_down == down) {
      return;
    }
    setState(() => _down = down);
    widget.onChanged(down);
  }

  @override
  void dispose() {
    if (_down) {
      widget.onChanged(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: widget.size,
        height: widget.size,
        decoration: ShapeDecoration(
          color: _down ? widget.accent : widget.accent.withValues(alpha: 0.55),
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(widget.size * 0.22),
            side: BorderSide(
              color: _down ? BwColors.amber : BwColors.sand,
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: widget.size * 0.42, color: BwColors.text),
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: BwColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
