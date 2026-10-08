import 'dart:async';

import 'package:flutter/material.dart';

import '../game/space_game.dart';

class CountdownOverlay extends StatefulWidget {
  const CountdownOverlay({required this.game, super.key});

  final SpaceGame game;

  @override
  State<CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<CountdownOverlay> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startedAt = widget.game.round?.startedAt ?? 0;
    final remainingMs = startedAt - DateTime.now().millisecondsSinceEpoch;
    final seconds = (remainingMs / 1000).ceil().clamp(0, 9);
    return IgnorePointer(
      child: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Center(
          // Long map names shrink on upright phones instead of overflowing.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: widget.game.mapName,
                  builder: (context, name, _) => Text(
                    'GELÄNDE: ${name.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 18,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFFB300),
                      shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                    ),
                  ),
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: widget.game.conditionsLabel,
                  builder: (context, label, _) => label == null
                      ? const SizedBox()
                      : Text(
                          'WETTER: ${label.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 14,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE6E2D3),
                            shadows: [
                              Shadow(blurRadius: 8, color: Colors.black),
                            ],
                          ),
                        ),
                ),
                Text(
                  seconds > 0 ? '$seconds' : 'Feuer frei!',
                  style: const TextStyle(
                    fontSize: 96,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE6E2D3),
                    shadows: [Shadow(blurRadius: 24, color: Colors.amber)],
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: widget.game.touchMode,
                  builder: (context, touch, _) => touch
                      ? const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'LINKS FAHREN  ·  RECHTS DEN TURM ZIELEN',
                            style: TextStyle(
                              fontSize: 14,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFE6E2D3),
                              shadows: [
                                Shadow(blurRadius: 8, color: Colors.black),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
