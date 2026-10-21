import 'dart:async';

import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../game/tank_game.dart';
import '../l10n/l10n.dart';
import 'theme.dart';
import 'widgets/panel.dart';

class CountdownOverlay extends StatefulWidget {
  const CountdownOverlay({required this.game, super.key});

  final TankGame game;

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
        // Above the middle, where the own tank waits for the start.
        child: Align(
          alignment: const Alignment(0, -0.45),
          // Long map names shrink on upright phones instead of overflowing.
          // On a plate rather than with shadows, so it reads on any ground.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Panel(
              padding: const EdgeInsets.symmetric(
                horizontal: HzSpace.s32,
                vertical: HzSpace.s16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<String>(
                    valueListenable: widget.game.mapName,
                    builder: (context, name, _) => Text(
                      tr(
                        'GELÄNDE: ${name.toUpperCase()}',
                        'TERRAIN: ${name.toUpperCase()}',
                      ),
                      style: GameType.title,
                    ),
                  ),
                  ValueListenableBuilder<String?>(
                    valueListenable: widget.game.conditionsLabel,
                    builder: (context, label, _) => label == null
                        ? const SizedBox()
                        : Padding(
                            padding: const EdgeInsets.only(top: HzSpace.s4),
                            child: Text(
                              tr(
                                'WETTER: ${label.toUpperCase()}',
                                'WEATHER: ${label.toUpperCase()}',
                              ),
                              style: GameType.kennung,
                            ),
                          ),
                  ),
                  // The count in mono, as large as the screen allows; the
                  // call to fire in the expanded capitals of a headline.
                  Text(
                    seconds > 0
                        ? '$seconds'
                        : tr('Feuer frei!', 'Fire at will!').toUpperCase(),
                    style: seconds > 0
                        ? GameType.dataLarge.copyWith(fontSize: 96, height: 1.2)
                        // Same line height as the number: the plate
                        // keeps its height when the count runs out.
                        : GameType.display.copyWith(
                            height: 96 * 1.2 / GameType.display.fontSize!,
                          ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.game.touchMode,
                    builder: (context, touch, _) => touch
                        ? Padding(
                            padding: const EdgeInsets.only(top: HzSpace.s12),
                            child: Text(
                              tr(
                                'LINKS FAHREN  ·  RECHTS DEN TURM ZIELEN',
                                'LEFT TO DRIVE  ·  RIGHT TO AIM THE TURRET',
                              ),
                              style: GameType.kennung.copyWith(
                                color: GameColors.text,
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
      ),
    );
  }
}
