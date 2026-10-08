import 'package:flutter/material.dart';

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
        color: const Color(0x44000000),
        shape: BwShapes.card(),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListenableBuilder(
              listenable: Listenable.merge([
                TvInput.instance.count,
                PadScreen.instance.phones,
              ]),
              builder: (context, _) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, pad) in TvInput.instance.pads.indexed)
                    _Chip(
                      icon: pad.kind == TvPadKind.remote
                          ? Icons.settings_remote
                          : Icons.sports_esports,
                      label:
                          '${i + 1} · '
                          '${pad.kind == TvPadKind.remote ? 'Siri Remote' : 'Controller'}',
                    ),
                  for (final (_, name) in PadScreen.instance.phones.value)
                    _Chip(
                      icon: Icons.smartphone,
                      label: name.isEmpty ? tr('Handy', 'Phone') : name,
                    ),
                  if (TvInput.instance.pads.isEmpty &&
                      PadScreen.instance.phones.value.isEmpty)
                    Text(
                      tr(
                        'Kein Controller verbunden. Die Siri Remote steuert '
                            'die Menüs.',
                        'No controller connected. The Siri Remote steers '
                            'the menus.',
                      ),
                      style: const TextStyle(color: BwColors.textDim),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
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
        color: BwColors.panel,
        shape: BwShapes.chip(edge: BwColors.oliveLight),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: BwColors.amber),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
