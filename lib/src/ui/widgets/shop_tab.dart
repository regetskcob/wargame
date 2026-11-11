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
/// weight say "open", the ring says "here". The check's place and the
/// semibold width are kept on every tab, so nothing moves when the choice
/// changes.
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
    return OutlinedButton(
      style: open
          ? style.copyWith(
              backgroundColor: WidgetStatePropertyAll(GameColors.accentTint),
              foregroundColor: WidgetStatePropertyAll(GameColors.text),
            )
          : style,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: HzIconSize.inline,
            child: open
                ? ExcludeSemantics(
                    child: Icon(
                      HorizontSymbols.check,
                      size: HzIconSize.inline,
                      color: GameColors.accentText,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: HzSpace.s4),
          if (icon case final icon?)
            Icon(icon, size: HzIconSize.row)
          else
            _label(),
        ],
      ),
    );
  }

  /// The label at its weight, over an invisible semibold copy that keeps
  /// the width the same open or closed.
  Widget _label() {
    final base = labelStyle ?? const TextStyle();
    final bold = base.copyWith(fontWeight: FontWeight.w600);
    return Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [
        ExcludeSemantics(
          child: Visibility.maintain(
            visible: false,
            child: Text(label!, style: bold),
          ),
        ),
        Text(
          label!,
          style: open ? bold : base.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
