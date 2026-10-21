import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../game/tank_game.dart';
import '../l10n/l10n.dart';
import '../net/pad_link.dart';
import '../ui/theme.dart';
import '../ui/widgets/pad_pairing.dart';
import '../ui/widgets/panel.dart';
import 'tv_input.dart';

/// On the Apple TV's start page: which controllers are in, and the way to
/// pair a phone as one, as in the browser.
class TvControllers extends StatelessWidget {
  const TvControllers({required this.game, super.key});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: GameColors.sunken,
        shape: GameShapes.card(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(HzSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListenableBuilder(
              listenable: Listenable.merge([
                TvInput.instance.count,
                PadScreen.instance.phones,
              ]),
              builder: (context, _) => Wrap(
                spacing: HzSpace.s8,
                runSpacing: HzSpace.s8,
                children: [
                  for (final (i, pad) in TvInput.instance.pads.indexed)
                    _Chip(
                      icon: pad.kind == TvPadKind.remote
                          ? Icons.settings_remote_outlined
                          : Icons.sports_esports_outlined,
                      label:
                          '${i + 1} · '
                          '${pad.kind == TvPadKind.remote ? remoteName : 'Controller'}',
                    ),
                  for (final (_, name) in PadScreen.instance.phones.value)
                    _Chip(
                      icon: Icons.smartphone_outlined,
                      label: name.isEmpty ? tr('Handy', 'Phone') : name,
                    ),
                  if (TvInput.instance.pads.isEmpty &&
                      PadScreen.instance.phones.value.isEmpty)
                    Text(
                      onAppleTv
                          ? tr(
                              'Kein Controller verbunden. Die Siri Remote '
                                  'steuert die Menüs.',
                              'No controller connected. The Siri Remote '
                                  'steers the menus.',
                            )
                          : tr(
                              'Kein Controller verbunden. Die Fernbedienung '
                                  'steuert die Menüs.',
                              'No controller connected. The remote steers '
                                  'the menus.',
                            ),
                      style: GameType.callout.copyWith(
                        color: GameColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const PadBusyNotice(),
            const SizedBox(height: HzSpace.s16),
            ControllerSection(game: game),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: GameColors.panel,
        shape: GameShapes.chip(edge: GameColors.lineStrong),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HzSpace.s12,
          vertical: HzSpace.s8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: HzIconSize.row, color: GameColors.textMuted),
            const SizedBox(width: HzSpace.s8),
            Text(
              label,
              style: GameType.label.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
