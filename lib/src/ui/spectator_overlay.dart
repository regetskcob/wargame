import 'package:flutter/material.dart';

import '../game/tank_game.dart';
import 'widgets/kill_feed_view.dart';
import 'widgets/leave_round.dart';
import 'widgets/mini_map.dart';
import 'theme.dart';
import 'widgets/panel.dart';
import '../l10n/l10n.dart';

class SpectatorOverlay extends StatelessWidget {
  const SpectatorOverlay({required this.game, super.key});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ValueListenableBuilder<RoundOutcome>(
          valueListenable: game.outcome,
          builder: (context, outcome, _) => outcome == RoundOutcome.lost
              ? const _DestroyedBanner()
              : const SizedBox(),
        ),
        // Clear of the notch, the Dynamic Island and the home indicator.
        SafeArea(
          minimum: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, box) {
              // Upright phones: the bar takes two lines at a readable size
              // and the kill feed moves under it instead of behind it.
              final narrow = box.maxWidth < 640;
              final gap = narrow ? 0.0 : 8.0;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    right: gap,
                    bottom: gap,
                    child: MiniMap(game: game, size: narrow ? 120 : 150),
                  ),
                  Padding(
                    padding: EdgeInsets.all(gap),
                    child: narrow
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _bar(narrow: true),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.topLeft,
                                child: KillFeedView(
                                  feed: game.killFeed,
                                  compact: true,
                                ),
                              ),
                            ],
                          )
                        : Stack(
                            children: [
                              KillFeedView(feed: game.killFeed),
                              Align(
                                alignment: Alignment.topCenter,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: _bar(narrow: false),
                                ),
                              ),
                            ],
                          ),
                  ),
                  // Bottom left: the bar, the kill feed and the map take
                  // the other corners.
                  if (!game.replaying.value)
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: LeaveRoundButton(game: game),
                    ),
                  // Always in reach, also on a phone where the bar above is
                  // cramped.
                  if (game.replaying.value)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: narrow ? 132 : 12),
                        child: FilledButton.icon(
                          onPressed: game.stopReplay,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: Text(
                            game.touchMode.value
                                ? tr('WIEDERHOLUNG BEENDEN', 'END REPLAY')
                                : tr(
                                    'WIEDERHOLUNG BEENDEN (ESC)',
                                    'END REPLAY (ESC)',
                                  ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        LeaveRoundPrompt(game: game),
      ],
    );
  }

  /// Who is being watched, how many are left and the switch to the next tank.
  Widget _bar({required bool narrow}) {
    final name = ValueListenableBuilder<String?>(
      valueListenable: game.spectatingName,
      builder: (context, name, _) => Text(
        name == null
            ? tr('Beobachte', 'Watching')
            : tr('Beobachte $name', 'Watching $name'),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
    final title = [
      if (game.replaying.value) ...[
        const Icon(Icons.movie_outlined, size: 18, color: GameColors.amber),
        const SizedBox(width: 6),
        Text(
          tr('WIEDERHOLUNG', 'REPLAY'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: GameColors.amber,
          ),
        ),
        const SizedBox(width: 12),
      ] else ...[
        const Icon(Icons.visibility, size: 18),
        const SizedBox(width: 8),
      ],
      if (narrow) Flexible(child: name) else name,
      const SizedBox(width: 12),
      ValueListenableBuilder<int>(
        valueListenable: game.aliveCount,
        builder: (context, alive, _) => Text(
          tr('noch $alive', '$alive left'),
          style: const TextStyle(color: GameColors.textDim),
        ),
      ),
    ];
    final next = ValueListenableBuilder<String?>(
      valueListenable: game.spectatingName,
      builder: (context, name, _) => ValueListenableBuilder<int>(
        valueListenable: game.aliveCount,
        builder: (context, alive, _) {
          final count = game.remoteTanks.length + game.botTanks.length;
          return Tooltip(
            message: count > 1
                ? tr('Zum nächsten Panzer wechseln', 'Switch to the next tank')
                : tr('Es ist nur ein Panzer im Feld', 'Only one tank is left'),
            child: TextButton(
              onPressed: count > 1 ? game.spectateNext : null,
              child: Text(
                count > 1
                    ? tr(
                        'NÄCHSTER PANZER (${game.spectateNumber}/$count)',
                        'NEXT TANK (${game.spectateNumber}/$count)',
                      )
                    : tr('NÄCHSTER PANZER', 'NEXT TANK'),
              ),
            ),
          );
        },
      ),
    );
    return Panel(
      padding: EdgeInsets.symmetric(horizontal: narrow ? 12 : 16, vertical: 8),
      child: narrow
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: title,
                ),
                next,
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [...title, const SizedBox(width: 12), next],
            ),
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
                  color: GameColors.danger.withValues(alpha: 0.28 * (1 - t)),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Transform.scale(
                        scale:
                            1.7 -
                            0.7 *
                                Curves.easeOutBack.transform(
                                  (t * 4).clamp(0.0, 1.0),
                                ),
                        child: Text(
                          tr('ZERSTÖRT', 'DESTROYED'),
                          style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 8,
                            color: GameColors.danger,
                            shadows: [
                              Shadow(blurRadius: 18, color: Colors.black),
                            ],
                          ),
                        ),
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
