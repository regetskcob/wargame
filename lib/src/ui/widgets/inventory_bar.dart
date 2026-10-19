import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../../game/inventory.dart';
import '../theme.dart';
import 'panel.dart';

/// The inventory down the left side of the screen: one slot per kind of
/// item, with its count and the number key that sets it off. A tap does the
/// same.
class InventoryBar extends StatelessWidget {
  const InventoryBar({
    required this.inventory,
    required this.onUse,
    this.compact = false,
    this.labels,
    super.key,
  });

  final Inventory inventory;
  final ValueChanged<int> onUse;
  final bool compact;

  /// What sets off each slot, in place of the number keys: the buttons of a
  /// controller on the Apple TV. An empty label shows nothing.
  final List<String>? labels;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<InventorySlot>>(
      valueListenable: inventory,
      builder: (context, slots, _) => InventoryStrip(
        slots: slots,
        onUse: onUse,
        compact: compact,
        labels: labels,
      ),
    );
  }
}

/// The slots of an inventory in a column, or in a row with [axis]: the
/// phone controller held sideways puts them between its thumbs.
class InventoryStrip extends StatelessWidget {
  const InventoryStrip({
    required this.slots,
    required this.onUse,
    this.compact = false,
    this.labels,
    this.axis = Axis.vertical,
    super.key,
  });

  final List<InventorySlot> slots;
  final ValueChanged<int> onUse;
  final bool compact;

  /// See [InventoryBar.labels].
  final List<String>? labels;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: axis,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Only what is there: empty frames on the left edge covered the
        // road the enemies come in on.
        for (var i = 0; i < slots.length; i++)
          Padding(
            padding: axis == Axis.vertical
                ? const EdgeInsets.symmetric(vertical: HzSpace.s2)
                : const EdgeInsets.symmetric(horizontal: HzSpace.s4),
            child: _Slot(
              slot: slots[i],
              label: labels == null
                  ? '${i + 1}'
                  : (i < labels!.length ? labels![i] : ''),
              compact: compact,
              onTap: () => onUse(i),
            ),
          ),
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.slot,
    required this.label,
    required this.compact,
    required this.onTap,
  });

  final InventorySlot slot;
  final String label;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = slot.type;
    final size = compact ? HzSize.touch : 56.0;
    final mark = GameType.kennung.copyWith(letterSpacing: 0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: ShapeDecoration(
          color: GameColors.panel,
          shape: GameShapes.chip(),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The icon keeps the colour of the item's crate in the
                  // field, so slot and pickup are recognised as one.
                  Icon(
                    type.icon,
                    size: compact ? HzIconSize.inline : HzIconSize.row,
                    color: type.color,
                  ),
                  const SizedBox(height: HzSpace.s2),
                  // The longest names (SCHNELLF., ARTILLERIE) were cut off
                  // in the 44 px slot of a phone; they shrink a little
                  // instead.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: HzSpace.s4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        type.short,
                        style: mark.copyWith(color: GameColors.text),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!compact)
              PositionedDirectional(
                start: HzSpace.s4,
                top: HzSpace.s2,
                child: Text(label, style: mark),
              ),
            if (slot.count > 1)
              PositionedDirectional(
                end: HzSpace.s4,
                top: HzSpace.s2,
                child: Text(
                  '×${slot.count}',
                  style: mark.copyWith(color: GameColors.text),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
