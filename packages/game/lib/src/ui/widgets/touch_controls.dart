import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/touch_input.dart';
import '../../theme.dart';

/// Steering on the left, throttle, brake and fire on the right and an aim
/// stick for the turret in between.
class TouchControls extends StatelessWidget {
  const TouchControls({required this.input, super.key});

  final TouchInput input;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 600;
          return Stack(
            children: [
              Align(
                alignment: Alignment.bottomLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HoldButton(
                      icon: Icons.rotate_left,
                      label: 'LINKS',
                      onChanged: (down) => input.left = down,
                    ),
                    const SizedBox(width: 12),
                    _HoldButton(
                      icon: Icons.rotate_right,
                      label: 'RECHTS',
                      onChanged: (down) => input.right = down,
                    ),
                  ],
                ),
              ),
              Align(
                alignment: wide ? Alignment.bottomCenter : Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.only(bottom: wide ? 0 : 96),
                  child: _AimStick(input: input),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HoldButton(
                          icon: Icons.keyboard_arrow_up,
                          label: 'VOR',
                          onChanged: (down) => input.thrust = down,
                        ),
                        const SizedBox(height: 12),
                        _HoldButton(
                          icon: Icons.keyboard_arrow_down,
                          label: 'BREMSE',
                          onChanged: (down) => input.brake = down,
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    _HoldButton(
                      icon: Icons.gps_fixed,
                      label: 'FEUER',
                      size: 112,
                      accent: BwColors.danger,
                      onChanged: (down) => input.fire = down,
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

/// Drag to point the turret. The angle stays after the finger lifts.
class _AimStick extends StatefulWidget {
  const _AimStick({required this.input});

  final TouchInput input;

  @override
  State<_AimStick> createState() => _AimStickState();
}

class _AimStickState extends State<_AimStick> {
  static const _size = 120.0;
  Offset _knob = Offset.zero;
  bool _active = false;

  void _update(Offset local) {
    final delta = local - const Offset(_size / 2, _size / 2);
    if (delta.distance < 10) {
      return;
    }
    widget.input.aim = atan2(delta.dx, -delta.dy);
    setState(() {
      _active = true;
      _knob = delta.distance > _size / 2 - 22
          ? delta / delta.distance * (_size / 2 - 22)
          : delta;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _update(e.localPosition),
      onPointerMove: (e) => _update(e.localPosition),
      onPointerUp: (_) => setState(() => _active = false),
      onPointerCancel: (_) => setState(() => _active = false),
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x66000000),
                border: Border.all(
                  color: _active ? BwColors.amber : BwColors.sand,
                  width: 2,
                ),
              ),
            ),
            const Positioned(
              top: 6,
              child: Text(
                'ZIELEN',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.5,
                  color: BwColors.textDim,
                ),
              ),
            ),
            Transform.translate(
              offset: _knob,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _active ? BwColors.amber : BwColors.olive,
                  border: Border.all(color: BwColors.sand, width: 2),
                ),
                child: const Icon(Icons.gps_fixed, size: 20),
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
