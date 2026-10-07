import 'package:flutter/material.dart';

import '../game/space_game.dart';
import 'widgets/kill_feed_view.dart';
import 'widgets/mini_map.dart';
import '../theme.dart';
import 'widgets/panel.dart';

class SpectatorOverlay extends StatelessWidget {
  const SpectatorOverlay({required this.game, super.key});

  final SpaceGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(right: 16, bottom: 16, child: MiniMap(game: game)),
        Positioned(left: 16, top: 16, child: KillFeedView(feed: game.killFeed)),
        ValueListenableBuilder<RoundOutcome>(
          valueListenable: game.outcome,
          builder: (context, outcome, _) => outcome == RoundOutcome.lost
              ? const _DestroyedBanner()
              : const SizedBox(),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Panel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (game.replaying.value) ...[
                    const Icon(
                      Icons.movie_outlined,
                      size: 18,
                      color: BwColors.amber,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'WIEDERHOLUNG',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: BwColors.amber,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ] else ...[
                    const Icon(Icons.visibility, size: 18),
                    const SizedBox(width: 8),
                  ],
                  ValueListenableBuilder<String?>(
                    valueListenable: game.spectatingName,
                    builder: (context, name, _) =>
                        Text(name == null ? 'Beobachte' : 'Beobachte $name'),
                  ),
                  const SizedBox(width: 12),
                  ValueListenableBuilder<int>(
                    valueListenable: game.aliveCount,
                    builder: (context, alive, _) => Text(
                      'noch $alive',
                      style: const TextStyle(color: BwColors.textDim),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ValueListenableBuilder<String?>(
                    valueListenable: game.spectatingName,
                    builder: (context, name, _) => ValueListenableBuilder<int>(
                      valueListenable: game.aliveCount,
                      builder: (context, alive, _) {
                        final count =
                            game.remoteShips.length + game.botShips.length;
                        return Tooltip(
                          message: count > 1
                              ? 'Zum nächsten Panzer wechseln'
                              : 'Es ist nur ein Panzer im Feld',
                          child: TextButton(
                            onPressed: count > 1 ? game.spectateNext : null,
                            child: Text(
                              count > 1
                                  ? 'NÄCHSTER PANZER (${game.spectateNumber}/$count)'
                                  : 'NÄCHSTER PANZER',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (game.replaying.value)
                    TextButton(
                      onPressed: game.stopReplay,
                      child: const Text('BEENDEN'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Flashes over the screen for a moment when the player's own tank is lost.
class _DestroyedBanner extends StatelessWidget {
  const _DestroyedBanner();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 2800),
        builder: (context, t, _) {
          final fade = t < 0.12
              ? t / 0.12
              : t > 0.7
              ? ((1 - t) / 0.3).clamp(0.0, 1.0)
              : 1.0;
          return Opacity(
            opacity: fade,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: BwColors.danger.withValues(alpha: 0.28 * (1 - t)),
                ),
                Center(
                  child: Transform.scale(
                    scale:
                        1.7 -
                        0.7 *
                            Curves.easeOutBack.transform(
                              (t * 4).clamp(0.0, 1.0),
                            ),
                    child: const Text(
                      'ZERSTÖRT',
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                        color: BwColors.danger,
                        shadows: [Shadow(blurRadius: 18, color: Colors.black)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
