import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../theme.dart';

/// A tab of the defense shop that opens one list (the guns, the upgrades):
/// spelled out on a desktop and a television, only its [icon] on a phone.
///
/// The open list is Horizont's selection in the soft style, the tint alone,
/// without a line along the foot. On the television a control in focus
/// carries a ring in the accent, so the open tab also takes a check in
/// `accent-text` before its content and a semibold label: tint, check and
/// weight say "open", the ring says "here". Every tab is as wide as its open
/// form, so nothing moves when the choice changes; a closed tab centres its
/// content in that width.
class ShopTab extends StatelessWidget {
  /// A tab with a spelled-out [label].
  const ShopTab.label({
    required String this.label,
    required this.open,
    required this.onPressed,
    required this.style,
    required this.labelStyle,
    super.key,
  }) : icon = null;

  /// A tab with only an [icon]; the caller names it for the screen reader.
  const ShopTab.icon({
    required IconData this.icon,
    required this.open,
    required this.onPressed,
    required this.style,
    super.key,
  }) : label = null,
       labelStyle = null;

  /// The name of the list, or null for an icon tab.
  final String? label;

  /// The symbol of the list, or null for a spelled-out tab.
  final IconData? icon;

  /// Whether this tab's list is the open one.
  final bool open;

  /// Opens (or closes) the list.
  final VoidCallback onPressed;

  /// The panel's button style the tab builds on.
  final ButtonStyle style;

  /// The label's size; the weight is the tab's own.
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    // An icon tab carries the check of the open one too: a little room on
    // both sides, so it does not touch the edge.
    final base = icon == null
        ? style
        : style.copyWith(
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: HzSpace.s4),
            ),
          );
    return OutlinedButton(
      style: open
          ? base.copyWith(
              backgroundColor: WidgetStatePropertyAll(GameColors.accentTint),
              foregroundColor: WidgetStatePropertyAll(GameColors.text),
            )
          : base,
      onPressed: onPressed,
      // The open form (check and semibold content) sets the width on every
      // tab, so nothing moves when the choice changes; a closed tab centres
      // its content in that width instead of leaving the check's place as a
      // gap at the start.
      child: Stack(
        alignment: Alignment.center,
        children: [
          ExcludeSemantics(
            child: Visibility.maintain(visible: false, child: _openRow()),
          ),
          if (open) _openRow() else _content(bold: false),
        ],
      ),
    );
  }

  /// The check, a small gap and the content in its open weight.
  Widget _openRow() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ExcludeSemantics(
        child: Icon(
          HorizontSymbols.check,
          size: HzIconSize.inline,
          color: GameColors.accentText,
        ),
      ),
      const SizedBox(width: HzSpace.s4),
      _content(bold: true),
    ],
  );

  /// The icon, or the label semibold when open and at 500 when closed.
  Widget _content({required bool bold}) {
    if (icon case final icon?) return Icon(icon, size: HzIconSize.row);
    final base = labelStyle ?? const TextStyle();
    return Text(
      label!,
      style: base.copyWith(
        fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}
