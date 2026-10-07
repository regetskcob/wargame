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
      child: Center(
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
            Text(
              seconds > 0 ? '$seconds' : 'Feuer frei!',
              style: const TextStyle(
                fontSize: 96,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE6E2D3),
                shadows: [Shadow(blurRadius: 24, color: Colors.amber)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
