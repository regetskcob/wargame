import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../app/overlay_ids.dart';
import '../game/game_phase.dart';
import '../game/tank_game.dart';
import '../ui/countdown_overlay.dart';
import '../ui/hud_overlay.dart';
import '../ui/round_over_overlay.dart';
import '../ui/spectator_overlay.dart';
import '../ui/widgets/tablet_scale.dart';
import 'seats.dart';
import 'second_player.dart';

/// The first player's game, and beside it in a round the second player's,
/// each half from its own tank. Between rounds the first player's menus
/// take the whole screen, the second game waits unseen and follows along.
class TvSplitView extends StatelessWidget {
  const TvSplitView({
    required this.host,
    required this.second,
    required this.child,
    super.key,
  });

  final TankGame host;
  final SecondPlayer second;

  /// The first player's game with its menus.
  final Widget child;

  static const _inRound = {
    GamePhase.countdown,
    GamePhase.playing,
    GamePhase.spectating,
    GamePhase.roundOver,
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([second, host.phase]),
      builder: (context, _) {
        final guest = second.guest;
        final split = guest != null && _inRound.contains(host.phase.value);
        return LayoutBuilder(
          builder: (context, box) {
            // Side by side on a wide screen, one above the other on a tablet
            // held upright.
            final wide = box.maxWidth >= box.maxHeight;
            final full = Offset.zero & box.biggest;
            final first = wide
                ? Rect.fromLTRB(0, 0, box.maxWidth / 2 - 2, box.maxHeight)
                : Rect.fromLTRB(0, 0, box.maxWidth, box.maxHeight / 2 - 2);
            final second = wide
                ? Rect.fromLTRB(
                    box.maxWidth / 2 + 2,
                    0,
                    box.maxWidth,
                    box.maxHeight,
                  )
                : Rect.fromLTRB(
                    0,
                    box.maxHeight / 2 + 2,
                    box.maxWidth,
                    box.maxHeight,
                  );
            return Stack(
              children: [
                Positioned.fromRect(
                  rect: split ? first : full,
                  child: ClipRect(child: child),
                ),
                if (guest != null)
                  Positioned.fromRect(
                    rect: second,
                    // Unseen between rounds, but running: it joins the
                    // rounds of the room like any other pilot.
                    child: Offstage(
                      offstage: !split,
                      child: ExcludeFocus(
                        child: ClipRect(child: _guest(guest)),
                      ),
                    ),
                  ),
                if (split)
                  for (final (player, rect) in [first, second].indexed)
                    Positioned.fromRect(
                      rect: rect,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: playerColors[player],
                              width: 3,
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: PlayerTag(
                                player: player,
                                seat: player < this.second.seats.length
                                    ? this.second.seats[player]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _guest(TankGame guest) {
    return GameWidget<TankGame>(
      key: ObjectKey(guest),
      game: guest,
      autofocus: false,
      overlayBuilderMap: {
        // The first player runs the menus.
        OverlayIds.lobby: (context, game) => const SizedBox.shrink(),
        OverlayIds.countdown: (context, game) => CountdownOverlay(game: game),
        OverlayIds.hud: (context, game) =>
            TabletScale(child: HudOverlay(game: game)),
        OverlayIds.spectator: (context, game) => SpectatorOverlay(game: game),
        OverlayIds.roundOver: (context, game) => RoundOverOverlay(game: game),
        OverlayIds.closed: (context, game) => const SizedBox.shrink(),
        OverlayIds.tutorial: (context, game) => const SizedBox.shrink(),
      },
    );
  }
}
