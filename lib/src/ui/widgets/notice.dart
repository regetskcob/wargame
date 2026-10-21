import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

/// A note in a row: the status tint as ground, its sign in the status
/// colour and the text in ink, radius 6 like the buttons beside it.
/// Horizont's "Hinweis", for a word before an action or about the room,
/// never instead of a status badge.
class Notice extends StatelessWidget {
  const Notice(this.status, {required this.child, this.icon, super.key});

  final HorizontStatus status;
  final Widget child;

  /// A sign of the game's own instead of the status sign.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = HorizontTheme.of(context).colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: status.tint(colors),
        borderRadius: BorderRadius.circular(HzRadius.r6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HzSpace.s12,
          vertical: HzSpace.s12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon ?? status.icon,
              size: HzIconSize.row,
              color: status.color(colors),
            ),
            const SizedBox(width: HzSpace.s12),
            Expanded(
              child: DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.bodyMedium,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
